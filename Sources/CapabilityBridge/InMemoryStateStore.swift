/// In-memory state store for tests and isolated demos.

import Foundation

/// Volatile store. All state is lost when the actor is deallocated.
public actor InMemoryStateStore: StateStore {
    private var states: [String: TaskState] = [:]

    public init() {}

    public func save(_ state: TaskState) async throws {
        var mutable = state
        mutable.updatedAt = Date()
        states[state.taskRef] = mutable
    }

    public func load(taskRef: String) async throws -> TaskState? {
        states[taskRef]
    }

    public func list() async throws -> [String] {
        Array(states.keys)
    }

    public func delete(taskRef: String) async throws {
        states.removeValue(forKey: taskRef)
    }
}
