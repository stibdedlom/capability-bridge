import Foundation
import WorkspaceTypes

/// Adapts COG-facing types into the canonical `CogTaskFrame` used by the
/// SDL capability bridge.
///
/// V0 is observe/advise only: `adapt(response:)` returns `nil` because no
/// capability packet is generated for an approval response in this scope.
public actor CogIntentAdapter {

    public init() {}

    /// Produce a task frame from a COG intent and its bounded context.
    public func adapt(intent: CogIntent, context: CogContext) -> CogTaskFrame {
        CogTaskFrame(
            contractVersion: intent.contractVersion,
            traceID: intent.traceID,
            intent: intent,
            context: context,
            scope: .observe,
            riskTier: riskTier(for: intent),
            autonomyMode: "advise",
            requestedOutcome: intent.userGoal,
            constraints: [],
            openQuestions: [],
            status: .new,
            createdAt: intent.timestamp
        )
    }

    /// V0 stub: approval responses do not produce a capability packet in
    /// observe/advise mode.
    /// TODO(bridge-v1): generate a capability packet when the scope supports
    /// autonomous execution.
    public func adapt(response: CogApprovalResponse) -> SdlCapabilityPacket? {
        nil
    }

    // MARK: - Risk Classification

    private func riskTier(for intent: CogIntent) -> RiskTier {
        intent.sourceIntent.action.riskTier
    }
}
