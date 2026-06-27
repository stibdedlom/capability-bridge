/// SDL-backed durable state store adapter.
///
/// Hydration and dehydration go through SDL lifecycle records and trace events.
/// This adapter is a placeholder for the real SDL integration; it records the
/// intended interface without implementing the wire protocol.

import CapabilityBridge
import Foundation

/// Adapter that persists `TaskState` to SDL lifecycle records.
///
/// In a full implementation this would call SDL lifecycle APIs. V0 keeps the
/// adapter as a typed boundary so the bridge can switch stores without changing
/// orchestration logic.
public actor SDLStateStore: StateStore {
    public enum Mode: Sendable, Equatable {
        case readOnly
        case readWrite
    }

    public let mode: Mode

    public init(mode: Mode = .readOnly) {
        self.mode = mode
    }

    public func save(_ state: TaskState) async throws {
        guard mode == .readWrite else {
            throw StateStoreError.persistenceFailed(
                "SDL state store is in read-only mode"
            )
        }
        // V0: no-op. Real implementation would write to SDL lifecycle record.
        _ = state
    }

    public func load(taskRef: String) async throws -> TaskState? {
        // V0: no-op. Real implementation would read from SDL lifecycle record.
        _ = taskRef
        return nil
    }

    public func list() async throws -> [String] {
        // V0: no-op.
        return []
    }

    public func delete(taskRef: String) async throws {
        guard mode == .readWrite else {
            throw StateStoreError.persistenceFailed(
                "SDL state store is in read-only mode"
            )
        }
        _ = taskRef
    }
}
