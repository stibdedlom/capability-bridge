import Foundation

/// Compact result returned to COG after the bridge processes an intent.
///
/// This type intentionally does not carry large artifacts or raw capability
/// output; it carries references and summaries so COG can decide how to
/// render them on surfaces.
public struct BridgeResult: Sendable, Codable, Equatable {
    public let traceId: String
    public let taskFrame: TaskFrame
    public let capabilityPlan: CapabilityPlan
    public let capabilityPacket: CapabilityPacket?
    public let contextBundleRef: String?
    public let status: String
    public let summary: String

    public init(
        traceId: String,
        taskFrame: TaskFrame,
        capabilityPlan: CapabilityPlan,
        capabilityPacket: CapabilityPacket? = nil,
        contextBundleRef: String? = nil,
        status: String,
        summary: String
    ) {
        self.traceId = traceId
        self.taskFrame = taskFrame
        self.capabilityPlan = capabilityPlan
        self.capabilityPacket = capabilityPacket
        self.contextBundleRef = contextBundleRef
        self.status = status
        self.summary = summary
    }

    enum CodingKeys: String, CodingKey {
        case traceId
        case taskFrame
        case capabilityPlan
        case capabilityPacket
        case contextBundleRef
        case status
        case summary
    }
}
