import Foundation
import CapabilityBridge

/// Errors thrown while adapting bridge plans to SDL capability packets.
public enum SDLAdapterError: Error, Sendable {
    /// The plan has no selectable primary route.
    case noPrimaryRoute(taskFrameRef: String)

    /// The plan requires authority that has not been granted.
    case missingAuthority(requirement: String)

    /// The lifecycle record reference is malformed or missing.
    case invalidLifecycleRecordRef(String)
}

/// Adapts a `CapabilityPlan` into the SDL-facing `CapabilityPacket` and
/// `ContextBundle` shapes.
///
/// The adapter is stateless and `Sendable`; it performs no I/O and emits no
/// trace events directly. Callers are responsible for emitting
/// `capability.invoked` / `capability.completed` traces around invocation.
public struct SDLAdapter: Sendable {

    /// Default invocation mode used when the plan does not specify one.
    public static let defaultInvocationMode = "dry-run"

    /// Identifier of the SDL capability registry that this adapter targets.
    public let registryRef: String

    /// Optional lifecycle record to attach to every packet produced.
    public let lifecycleRecordRef: String?

    public init(registryRef: String = "sdl://registry/default", lifecycleRecordRef: String? = nil) {
        self.registryRef = registryRef
        self.lifecycleRecordRef = lifecycleRecordRef
    }

    /// Translate a plan into a capability packet ready for SDL routing.
    ///
    /// - Parameters:
    ///   - plan: The bridge routing plan.
    ///   - contextBundle: The bounded context to attach.
    ///   - contextBundleRef: A stable reference for the context bundle.
    ///   - approvedScope: Optional scope approved by a human approval surface.
    ///     When provided, the packet's authority is intersected with this scope.
    /// - Returns: A `CapabilityPacket` with mutation authority derived from the
    ///   plan, its primary route, and any approved scope.
    public func adapt(
        plan: CapabilityPlan,
        contextBundle: ContextBundle,
        contextBundleRef: String,
        approvedScope: [String]? = nil
    ) throws -> CapabilityPacket {
        guard !plan.primaryRoute.capability.isEmpty else {
            throw SDLAdapterError.noPrimaryRoute(taskFrameRef: plan.taskFrameRef)
        }

        let invocationMode = plan.primaryRoute.invocationMode.isEmpty
            ? Self.defaultInvocationMode
            : plan.primaryRoute.invocationMode

        let effectiveAuthority = effectiveAuthorityScope(plan: plan, approvedScope: approvedScope)
        let requiresApproval = plan.authorityRequired.contains("approval-gate")
        let approved = approvedScope.map { !$0.isEmpty } ?? !requiresApproval
        let allowMutation = invocationMode == "execute" && approved

        var inputs: [String: String] = [
            "taskFrameRef": plan.taskFrameRef,
            "primaryCapability": plan.primaryRoute.capability,
            "registryRef": registryRef,
            "tracePolicy": plan.tracePolicy,
            "estimatedRiskTier": plan.estimatedRiskTier
        ]

        if !plan.fallbackRoutes.isEmpty {
            inputs["fallbackCapabilities"] = plan.fallbackRoutes.map(\.capability).joined(separator: ",")
        }

        if let lifecycleRecordRef, !lifecycleRecordRef.isEmpty {
            inputs["lifecycleRecordRef"] = lifecycleRecordRef
        }

        if let snapshot = contextBundle.workspaceSnapshot {
            inputs["workspaceSnapshotSummary"] = snapshot
        }

        return CapabilityPacket(
            mode: plan.primaryRoute.capability,
            selectedCapability: plan.primaryRoute.capability,
            invocationMode: invocationMode,
            inputs: inputs,
            contextBundleRef: contextBundleRef,
            authorityScope: effectiveAuthority,
            allowMutation: allowMutation,
            expectedOutputs: ["artifactSummary", "traceEventBatch"]
        )
    }

    private func effectiveAuthorityScope(plan: CapabilityPlan, approvedScope: [String]?) -> [String] {
        guard let approvedScope else { return plan.authorityRequired }
        let approvedSet = Set(approvedScope)
        return plan.authorityRequired.filter { approvedSet.contains($0) || $0 == "approval-gate" }
    }

    /// Build a context bundle for the given task frame and plan.
    ///
    /// This is a convenience assembler. In production the bundle may be
    /// produced by a separate provenance service; the adapter only needs the
    /// resulting reference.
    public func assembleContextBundle(
        for frame: TaskFrame,
        plan: CapabilityPlan? = nil
    ) -> (ref: String, bundle: ContextBundle) {
        let ref = "context-bundle:\(frame.taskRef)"
        var aurRefs: [String] = []
        var omissions: [String] = []

        if plan == nil {
            omissions.append("No capability plan available at bundle assembly time")
        }

        if frame.riskTier == "high" || frame.riskTier == "critical" {
            omissions.append("Sensitive workspace details redacted due to riskTier=\(frame.riskTier)")
        }

        if let repo = frame.repoContext, !repo.isEmpty {
            aurRefs.append("aur://repo/\(repo)")
        }

        let bundle = ContextBundle(
            workspaceSnapshot: frame.workspaceTarget,
            noteRefs: [],
            memorySnippets: [],
            artifactRefs: [],
            aurRefs: aurRefs,
            omissions: omissions,
            freshness: Date(),
            tokenBudget: 4096,
            rawContentPolicy: frame.riskTier == "high" || frame.riskTier == "critical" ? "redact-sensitive" : "include"
        )

        return (ref, bundle)
    }
}
