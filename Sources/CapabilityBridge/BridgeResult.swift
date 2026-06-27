import Foundation

/// Compact result returned to COG after the bridge processes an intent.
///
/// This type intentionally does not carry large artifacts or raw capability
/// output; it carries references and summaries so COG can decide how to
/// render them on surfaces.
public struct BridgeResult: Sendable {
    public var traceId: String
    public var taskFrame: TaskFrame
    public var capabilityPlan: CapabilityPlan
    public var capabilityPacket: CapabilityPacket?
    public var contextBundleRef: String?
    public var status: String
    public var summary: String

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
}
