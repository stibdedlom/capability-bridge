import Foundation

/// Response from a COG-owned approval surface.
///
/// The bridge produces `ApprovalRequest`s; COG surfaces render them and
/// return this response. The bridge never owns the human-facing surface.
public struct BridgeApprovalResponse: Sendable, Codable, Equatable {
    public let requestRef: String
    public let approvalState: ApprovalState
    public let approvedScope: [String]
    public let deniedActions: [String]
    public let respondedAt: Date

    public init(
        requestRef: String,
        approvalState: ApprovalState,
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
        approvalState == .approved
    }

    enum CodingKeys: String, CodingKey {
        case requestRef
        case approvalState
        case approvedScope
        case deniedActions
        case respondedAt
    }
}
