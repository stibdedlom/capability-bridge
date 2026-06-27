import Foundation
import CapabilityBridge
import CapabilityBridgeSDL

/// Errors thrown while handling COG intents through the bridge.
public enum COGAdapterError: Error, Sendable {
    /// The planner produced a plan but no route could be selected.
    case noRouteSelected(taskFrameRef: String)

    /// The SDL adapter could not translate the plan.
    case adaptationFailed(underlying: Error)

    /// Trace emission failed.
    case traceFailed(underlying: Error)
}

/// COG-facing adapter that orchestrates the full bridge pipeline.
///
/// `COGAdapter` is an `actor` because it owns a `TraceEventEmitter` actor.
/// All public entry points are `async` and safe to call from COG surfaces.
public actor COGAdapter {

    public var planner: any CapabilityPlanner
    public var sdlAdapter: SDLAdapter
    public var traceEmitter: TraceEventEmitter
    public var includePacketInResult: Bool

    public init(
        planner: any CapabilityPlanner = DefaultCapabilityPlanner(),
        sdlAdapter: SDLAdapter = SDLAdapter(),
        traceEmitter: TraceEventEmitter,
        includePacketInResult: Bool = true
    ) {
        self.planner = planner
        self.sdlAdapter = sdlAdapter
        self.traceEmitter = traceEmitter
        self.includePacketInResult = includePacketInResult
    }

    /// Handle a raw COG intent end-to-end.
    ///
    /// Pipeline:
    /// 1. Frame the intent into a `TaskFrame`.
    /// 2. Produce a `CapabilityPlan`.
    /// 3. Assemble a `ContextBundle`.
    /// 4. Adapt the plan into a `CapabilityPacket`.
    /// 5. Emit trace events for the entire flow.
    /// 6. Return a `BridgeResult` summary for COG display.
    public func handle(intent: Intent) async throws -> BridgeResult {
        let frame = try await planner.frame(intent: intent)
        let plan = try await planner.plan(frame: frame)

        let (contextBundleRef, contextBundle) = sdlAdapter.assembleContextBundle(for: frame, plan: plan)
        let packet = includePacketInResult
            ? try sdlAdapter.adapt(plan: plan, contextBundle: contextBundle, contextBundleRef: contextBundleRef)
            : nil

        let traceId: String
        do {
            traceId = try await traceEmitter.tracePipeline(
                intent: intent,
                frame: frame,
                plan: plan,
                packet: packet
            )
        } catch {
            throw COGAdapterError.traceFailed(underlying: error)
        }

        let summary = makeSummary(intent: intent, frame: frame, plan: plan, packet: packet)

        return BridgeResult(
            traceId: traceId,
            taskFrame: frame,
            capabilityPlan: plan,
            capabilityPacket: packet,
            contextBundleRef: contextBundleRef,
            status: "ok",
            summary: summary
        )
    }

    /// Handle a framed task directly (useful when COG has already framed the
    /// intent or when replaying a persisted task).
    public func handle(frame: TaskFrame) async throws -> BridgeResult {
        let plan = try await planner.plan(frame: frame)

        let (contextBundleRef, contextBundle) = sdlAdapter.assembleContextBundle(for: frame, plan: plan)
        let packet = includePacketInResult
            ? try sdlAdapter.adapt(plan: plan, contextBundle: contextBundle, contextBundleRef: contextBundleRef)
            : nil

        return BridgeResult(
            traceId: "",
            taskFrame: frame,
            capabilityPlan: plan,
            capabilityPacket: packet,
            contextBundleRef: contextBundleRef,
            status: "ok",
            summary: makeSummary(intent: nil, frame: frame, plan: plan, packet: packet)
        )
    }

    // MARK: - Helpers

    private func makeSummary(
        intent: Intent?,
        frame: TaskFrame,
        plan: CapabilityPlan,
        packet: CapabilityPacket?
    ) -> String {
        let source = intent?.source ?? frame.sourceIntent
        let capability = plan.primaryRoute.capability
        let mode = packet?.invocationMode ?? plan.primaryRoute.invocationMode
        let mutation = packet?.allowMutation == true ? "mutation-allowed" : "dry-run"
        return "[\(source)] \(frame.userGoal) -> \(capability) (\(mode), \(mutation)) with \(plan.fallbackRoutes.count) fallback(s)"
    }
}
