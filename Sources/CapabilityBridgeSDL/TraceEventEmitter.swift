import Foundation
import WorkspaceTypes

/// Accepts `CogTraceEvent` values and forwards them to SDL lifecycle records.
///
/// V0 is a no-op implementation that only prints to standard output so tests
/// and local runs can observe that events reached the emitter.
public actor TraceEventEmitter {

    public init() {}

    /// Record the event. V0 does not persist.
    public func emit(_ event: CogTraceEvent) {
        print("[trace] \(event.traceID) \(event.eventType): \(event.outcome)")
    }
}
