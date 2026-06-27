import Foundation
import WorkspaceTypes

/// SDL-side adapter that conforms to the shared `CapabilityBridgeClient`.
///
/// V0 returns observe/advise-only plans, never mutates the host, and ignores
/// approval responses (returning no artifact).
public actor SdlBridgeAdapter: CapabilityBridgeClient {

    private let planResponder = CapabilityPlanResponder()
    private let traceEmitter = TraceEventEmitter()

    public init() {}

    /// Submit a task frame and receive an observe/advise-only plan.
    public func submit(_ frame: CogTaskFrame) async -> Result<SdlCapabilityPlan, CogBridgeError> {
        let plan = planResponder.plan(for: frame)
        return .success(plan)
    }

    /// Respond to an approval request. V0 does not execute, so no artifact is
    /// produced.
    public func respond(
        to approvalRef: String,
        with response: CogApprovalResponse
    ) async -> Result<SdlArtifactSummary?, CogBridgeError> {
        _ = approvalRef
        _ = response
        return .success(nil)
    }

    /// Emit a trace event into the SDL lifecycle record. V0 logs and discards.
    public func emit(_ event: CogTraceEvent) async -> Result<Void, CogBridgeError> {
        await traceEmitter.emit(event)
        return .success(())
    }
}
