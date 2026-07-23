import Foundation

/// Protocol-oriented facade for SDL-facing adapters.
///
/// Concrete adapters (e.g. `SDLAdapter`) conform to this protocol so the
/// COG adapter can be tested with stubs and swapped without changing core
/// bridge contracts.
public protocol SDLAdapterProtocol: Sendable {
    /// Translate a plan into a capability packet ready for SDL routing.
    func adapt(
        plan: CapabilityPlan,
        contextBundle: ContextBundle,
        contextBundleRef: String,
        approvedScope: [String]?
    ) throws -> CapabilityPacket

    /// Build a context bundle for the given task frame and plan.
    func assembleContextBundle(
        for frame: TaskFrame,
        plan: CapabilityPlan?
    ) -> (ref: String, bundle: ContextBundle)
}

/// Protocol-oriented facade for COG-facing adapters.
///
/// `COGAdapter` is the production implementation, but the protocol allows
/// tests and alternative surfaces to plug in a different orchestrator.
public protocol COGAdapterProtocol: Sendable {
    /// Handle a raw COG intent end-to-end.
    func handle(intent: Intent) async throws -> BridgeResult

    /// Handle a framed task directly.
    func handle(frame: TaskFrame) async throws -> BridgeResult
}
