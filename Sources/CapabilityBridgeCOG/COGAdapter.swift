import Foundation
import CapabilityBridge
import CapabilityBridgeSDL
import ApprovalSurfaces

/// Errors thrown while handling COG intents through the bridge.
public enum COGAdapterError: Error, Sendable {
    /// The planner produced a plan but no route could be selected.
    case noRouteSelected(taskFrameRef: String)

    /// The SDL adapter could not translate the plan.
    case adaptationFailed(underlying: Error)

    /// Trace emission failed.
    case traceFailed(underlying: Error)

    /// Approval was required but the surface denied or failed.
    case approvalDenied(requestRef: String)
}

/// COG-facing adapter that orchestrates the full bridge pipeline.
///
/// `COGAdapter` is an `actor` because it owns a `TraceEventEmitter` actor.
/// All public entry points are `async` and safe to call from COG surfaces.
public actor COGAdapter {

    public var planner: any CapabilityPlanner
    public var sdlAdapter: SDLAdapter
    public var traceEmitter: TraceEventEmitter
    public var approvalSurface: (any ApprovalSurface)?
    public var includePacketInResult: Bool

    public init(
        planner: any CapabilityPlanner = DefaultCapabilityPlanner(),
        sdlAdapter: SDLAdapter = SDLAdapter(),
        traceEmitter: TraceEventEmitter,
        approvalSurface: (any ApprovalSurface)? = nil,
        includePacketInResult: Bool = true
    ) {
        self.planner = planner
        self.sdlAdapter = sdlAdapter
        self.traceEmitter = traceEmitter
        self.approvalSurface = approvalSurface
        self.includePacketInResult = includePacketInResult
    }

    /// Handle a raw COG intent end-to-end.
    public func handle(intent: Intent) async throws -> BridgeResult {
        let frame = try await planner.frame(intent: intent)
        return try await handle(frame: frame, intent: intent)
    }

    /// Handle a framed task directly. Approval gating is applied the same way
    /// as for raw intents.
    public func handle(frame: TaskFrame) async throws -> BridgeResult {
        try await handle(frame: frame, intent: nil)
    }

    // MARK: - Private pipeline

    private func handle(frame: TaskFrame, intent: Intent?) async throws -> BridgeResult {
        let plan = try await planner.plan(frame: frame)

        let pipelineResult: TraceEventEmitter.TracePipelineResult
        do {
            pipelineResult = try await traceEmitter.tracePipeline(
                intent: intent ?? syntheticIntent(from: frame),
                frame: frame,
                plan: plan,
                packet: nil
            )
        } catch {
            throw COGAdapterError.traceFailed(underlying: error)
        }

        let approval = try await resolveApprovalIfNeeded(
            plan: plan,
            frame: frame,
            traceId: pipelineResult.traceId,
            parentEventId: pipelineResult.planProducedEventId
        )

        let (contextBundleRef, contextBundle) = sdlAdapter.assembleContextBundle(for: frame, plan: plan)
        let packet = includePacketInResult
            ? try sdlAdapter.adapt(
                plan: plan,
                contextBundle: contextBundle,
                contextBundleRef: contextBundleRef,
                approvedScope: approval?.1.approvedScope
            )
            : nil

        if let packet {
            do {
                let invokedEvent = try await traceEmitter.capabilityInvoked(
                    packet,
                    parentEventId: pipelineResult.primaryRouteEventId,
                    traceId: pipelineResult.traceId
                )
                _ = try await traceEmitter.capabilityCompleted(
                    capability: packet.selectedCapability ?? packet.mode,
                    outcome: "success",
                    parentEventId: invokedEvent.eventId,
                    traceId: pipelineResult.traceId
                )
            } catch {
                throw COGAdapterError.traceFailed(underlying: error)
            }
        }

        let summary = makeSummary(intent: intent, frame: frame, plan: plan, packet: packet, response: approval?.1)

        return BridgeResult(
            traceId: pipelineResult.traceId,
            taskFrame: frame,
            capabilityPlan: plan,
            capabilityPacket: packet,
            contextBundleRef: contextBundleRef,
            status: approval?.1.approvalState == "denied" ? "approval-denied" : "ok",
            summary: summary
        )
    }

    // MARK: - Approval

    private func resolveApprovalIfNeeded(
        plan: CapabilityPlan,
        frame: TaskFrame,
        traceId: String,
        parentEventId: String?
    ) async throws -> (ApprovalRequest, BridgeApprovalResponse)? {
        guard plan.authorityRequired.contains("approval-gate") else { return nil }

        guard let surface = approvalSurface else {
            throw COGAdapterError.approvalDenied(requestRef: "approval-surface-not-configured")
        }

        let request = makeApprovalRequest(for: plan, frame: frame)
        let requestedEvent = try await traceEmitter.approvalRequested(request, parentEventId: parentEventId, traceId: traceId)

        let response: BridgeApprovalResponse
        do {
            response = try await surface.present(request: request)
        } catch {
            _ = try? await traceEmitter.traceError(
                message: "Approval surface failed: \(error)",
                subjectRef: request.scope,
                parentEventId: requestedEvent.eventId,
                traceId: traceId
            )
            throw COGAdapterError.approvalDenied(requestRef: "surface-failure")
        }

        _ = try await traceEmitter.approvalResolved(
            request: request,
            response: response,
            parentEventId: requestedEvent.eventId,
            traceId: traceId
        )

        guard response.isApproved else {
            throw COGAdapterError.approvalDenied(requestRef: response.requestRef)
        }

        return (request, response)
    }

    // MARK: - Helpers

    private func makeApprovalRequest(for plan: CapabilityPlan, frame: TaskFrame) -> ApprovalRequest {
        ApprovalRequest(
            riskTier: plan.estimatedRiskTier,
            requestedAction: "Execute \(plan.primaryRoute.capability) via \(plan.primaryRoute.invocationMode) mode",
            evidenceRefs: [plan.taskFrameRef],
            scope: plan.authorityRequired.joined(separator: ", "),
            prohibitedActions: ["access secrets", "exfiltrate data", "modify outside allowed paths"],
            confirmationRitual: "tap-approve",
            approvalState: "pending"
        )
    }

    private func syntheticIntent(from frame: TaskFrame) -> Intent {
        Intent(
            id: frame.taskRef,
            source: frame.sourceIntent,
            rawText: frame.userGoal,
            metadata: [
                "workspaceTarget": frame.workspaceTarget ?? "",
                "repoContext": frame.repoContext ?? ""
            ]
        )
    }

    private func makeSummary(
        intent: Intent?,
        frame: TaskFrame,
        plan: CapabilityPlan,
        packet: CapabilityPacket?,
        response: BridgeApprovalResponse?
    ) -> String {
        let source = intent?.source ?? frame.sourceIntent
        let capability = plan.primaryRoute.capability
        let mode = packet?.invocationMode ?? plan.primaryRoute.invocationMode
        let mutation = packet?.allowMutation == true ? "mutation-allowed" : "dry-run"
        let approval = response?.approvalState ?? "not-required"
        return "[\(source)] \(frame.userGoal) -> \(capability) (\(mode), \(mutation), approval=\(approval)) with \(plan.fallbackRoutes.count) fallback(s)"
    }
}
