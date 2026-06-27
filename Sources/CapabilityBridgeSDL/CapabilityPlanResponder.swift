import Foundation
import WorkspaceTypes

/// Builds SDL capability plans and approval requests from a `CogTaskFrame`.
///
/// V0 always returns a single observe/advise step. Medium- and high-risk
/// frames additionally generate a required approval reference.
package struct CapabilityPlanResponder: Sendable {

    package init() {}

    /// Build a one-step observe/advise plan for the given frame.
    package func plan(for frame: CogTaskFrame) -> SdlCapabilityPlan {
        let requiresApproval = frame.riskTier == .medium || frame.riskTier == .high
        let approvalRef = requiresApproval ? "approval-\(frame.traceID)" : nil
        let targets = targetRefs(from: frame.context)

        let step = SdlCapabilityPlanStep(
            id: "\(frame.traceID)-step-1",
            description: "Observe and advise: \(frame.intent.userGoal)",
            capability: "observe-advise",
            riskTier: frame.riskTier,
            requiresApproval: requiresApproval,
            targetRefs: targets
        )

        return SdlCapabilityPlan(
            contractVersion: frame.contractVersion,
            traceID: frame.traceID,
            taskFrameRef: frame.traceID,
            planID: "plan-\(frame.traceID)",
            steps: [step],
            estimatedRisk: frame.riskTier,
            requiredApprovals: approvalRef.map { [$0] } ?? [],
            targetRefs: targets,
            summary: "Advisory plan for \(frame.intent.userGoal)",
            constraints: frame.constraints
        )
    }

    /// Build the approval request associated with a medium- or high-risk plan.
    package func approvalRequest(for frame: CogTaskFrame, approvalRef: String) -> SdlApprovalRequest {
        let ritual: SdlConfirmationRitual = frame.riskTier == .high ? .explicitConfirm : .tapApprove
        return SdlApprovalRequest(
            contractVersion: frame.contractVersion,
            traceID: frame.traceID,
            approvalRef: approvalRef,
            taskFrameRef: frame.traceID,
            riskTier: frame.riskTier,
            requestedAction: frame.intent.userGoal,
            evidenceRefs: [],
            scope: frame.scope.rawValue,
            expiresAt: nil,
            prohibitedActions: ["mutate"],
            confirmationRitual: ritual,
            state: .pending
        )
    }

    // MARK: - Helpers

    private func targetRefs(from context: CogContext) -> [String] {
        var refs: [String] = []
        if let activeTab = context.activeTabID { refs.append(activeTab) }
        if let activeSurface = context.activeSurfaceID { refs.append(activeSurface) }
        return refs
    }
}
