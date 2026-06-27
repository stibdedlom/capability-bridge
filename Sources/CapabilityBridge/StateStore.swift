/// Storage protocol for task state hydration/dehydration.
///
/// The bridge does not own durable storage; SDL lifecycle records and trace
/// events do. This protocol abstracts the read/write boundary so tests and
/// adapters can substitute in-memory or SDL-backed stores.

import Foundation

/// Errors raised by state stores.
public enum StateStoreError: Error, Equatable {
    case notFound(String)
    case serializationFailed(String)
    case persistenceFailed(String)
}

/// A state store reads and writes `TaskState` snapshots.
public protocol StateStore: Sendable {
    /// Persist a task state snapshot.
    func save(_ state: TaskState) async throws

    /// Load the latest state for a task reference, if any.
    func load(taskRef: String) async throws -> TaskState?

    /// List persisted task references.
    func list() async throws -> [String]

    /// Remove a persisted task state.
    func delete(taskRef: String) async throws
}
