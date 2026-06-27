import Foundation
import WorkspaceTypes

/// Errors thrown by `MockPaneBackend`.
public enum MockPaneBackendError: Error, Sendable {
    case sessionNotFound
}

/// A pane backend that keeps sessions in memory for testing.
public actor MockPaneBackend: PaneBackend {

    private struct MockSession: Sendable {
        let id: String
        let role: String
        let command: String?
        var output: String
        var stopped: Bool
    }

    private var sessions: [String: MockSession] = [:]

    public init() {}

    public func spawnSession(id: String, role: String, command: String?) async throws -> String {
        sessions[id] = MockSession(
            id: id,
            role: role,
            command: command,
            output: "",
            stopped: false
        )
        return id
    }

    public func sendInput(sessionID: String, input: String) async throws {
        guard sessions[sessionID] != nil else {
            throw MockPaneBackendError.sessionNotFound
        }
        sessions[sessionID]?.output.append(input + "\n")
    }

    public func readOutput(sessionID: String) async throws -> Chunk {
        guard let session = sessions[sessionID] else {
            throw MockPaneBackendError.sessionNotFound
        }
        return Chunk(
            tabID: sessionID,
            index: 0,
            text: session.output,
            hasMore: false
        )
    }

    public func stopSession(sessionID: String) async throws {
        guard sessions[sessionID] != nil else {
            throw MockPaneBackendError.sessionNotFound
        }
        sessions[sessionID]?.stopped = true
    }
}
