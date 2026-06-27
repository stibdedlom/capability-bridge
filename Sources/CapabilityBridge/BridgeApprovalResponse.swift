import Foundation

/// Response from a COG-owned approval surface.
///
/// The bridge produces `ApprovalRequest`s; COG surfaces render them and
/// return this response. The bridge never owns the human-facing surface.
public struct BridgeApprovalResponse: Sendable {
    public var requestRef: String
    public var approvalState: String
    public var approvedScope: [String]
    public var deniedActions: [String]
    public var respondedAt: Date

    public init(
        requestRef: String,
        approvalState: String,
        approvedScope: [String] = [],
        deniedActions: [String] = [],
        respondedAt: Date = Date()
    ) {
        self.requestRef = requestRef
        self.approvalState = approvalState
        self.approvedScope = approvedScope
        self.deniedActions = deniedActions
        self.respondedAt = respondedAt
    }

    public var isApproved: Bool {
        approvalState == "approved"
    }
}
