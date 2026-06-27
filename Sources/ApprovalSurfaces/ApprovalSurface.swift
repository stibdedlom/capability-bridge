import CapabilityBridge

/// COG-owned surface that renders `ApprovalRequest`s and returns
/// `BridgeApprovalResponse`s.
///
/// The bridge provides this protocol so COG can plug in Mac, iPhone, Watch,
/// or other surfaces without the bridge owning UI, transport, or biometric
/// rituals.
public protocol ApprovalSurface: Sendable {
    /// Present the request to the user and return their response.
    func present(request: ApprovalRequest) async throws -> BridgeApprovalResponse
}

/// Test surface that always returns the configured response.
public actor StubApprovalSurface: ApprovalSurface {
    public var response: BridgeApprovalResponse

    public init(response: BridgeApprovalResponse) {
        self.response = response
    }

    public func present(request: ApprovalRequest) async throws -> BridgeApprovalResponse {
        response
    }
}
