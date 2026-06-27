import Foundation

/// A raw, surface-agnostic request from the human workspace (COG).
///
/// `Intent` is the bridge intake: it carries what the user said or did,
/// where it came from, and enough correlation context to produce a
/// `TaskFrame`. It intentionally does not contain routing decisions;
/// those are produced by the planner.
public struct Intent: Sendable {
    public var id: String
    public var source: String
    public var rawText: String
    public var locale: String
    public var timestamp: Date
    public var deviceRef: String?
    public var sessionRef: String?
    public var metadata: [String: String]

    public init(
        id: String,
        source: String,
        rawText: String,
        locale: String = "en-US",
        timestamp: Date = Date(),
        deviceRef: String? = nil,
        sessionRef: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.rawText = rawText
        self.locale = locale
        self.timestamp = timestamp
        self.deviceRef = deviceRef
        self.sessionRef = sessionRef
        self.metadata = metadata
    }
}
