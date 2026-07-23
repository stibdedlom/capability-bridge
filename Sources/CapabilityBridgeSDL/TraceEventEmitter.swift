import Foundation
import WorkspaceTypes

/// Accepts `CogTraceEvent` values and forwards them to SDL lifecycle records.
///
/// V0 is a no-op implementation. Trace data is intentionally not written to
/// standard output or any other sink until a redaction-aware logging policy is
/// defined.
/// TODO(bridge-v1): inject a logging protocol and emit redacted traces.
public actor TraceEventEmitter {

    public init() {}

    /// Record the event. V0 does not persist or print.
    public func emit(_ event: CogTraceEvent) {
        // Intentionally empty for V0.
    }
}
