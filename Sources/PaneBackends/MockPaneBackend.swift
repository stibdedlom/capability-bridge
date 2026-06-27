/// A mock pane backend for testing and safe prototyping.

import CapabilityBridge
import Foundation

/// In-memory backend that simulates visible sessions without touching tmux,
/// Zellij, or native windows. Useful for unit tests and V0 demos.
public actor MockPaneBackend: PaneBackend {
    public nonisolated let backendID: String
    private var sessions: [String: PaneSession] = [:]

    public init(backendID: String = "mock") {
        self.backendID = backendID
    }

    public func spawnSession(id: String, role: String, command: String?) async throws -> String {
        guard sessions[id] == nil else {
            throw PaneBackendError.sessionAlreadyExists(id)
        }
        var session = PaneSession(
            id: id,
            role: role,
            command: command,
            backendID: backendID,
            status: .spawning
        )
        session.markRunning()
        sessions[id] = session
        return id
    }

    public func sendInput(sessionID: String, input: String) async throws {
        guard sessions[sessionID] != nil else {
            throw PaneBackendError.sessionNotFound(sessionID)
        }
        sessions[sessionID]?.enqueueInput(input)
        sessions[sessionID]?.appendOutput(">> \(input)")
    }

    public func readOutput(sessionID: String) async throws -> String {
        guard let session = sessions[sessionID] else {
            throw PaneBackendError.sessionNotFound(sessionID)
        }
        return session.output.joined(separator: "\n")
    }

    public func stopSession(sessionID: String) async throws {
        guard sessions[sessionID] != nil else {
            throw PaneBackendError.sessionNotFound(sessionID)
        }
        sessions[sessionID]?.markStopped()
    }

    public func listSessions() async -> [PaneSessionSummary] {
        sessions.values.map(\.summary)
    }

    /// Simulate a session producing output. Exposed for tests only.
    public func simulateOutput(sessionID: String, output: String) async throws {
        guard sessions[sessionID] != nil else {
            throw PaneBackendError.sessionNotFound(sessionID)
        }
        sessions[sessionID]?.appendOutput(output)
    }

    /// Simulate a session becoming unresponsive. Exposed for tests only.
    public func simulateUnresponsive(sessionID: String) async throws {
        guard sessions[sessionID] != nil else {
            throw PaneBackendError.sessionNotFound(sessionID)
        }
        sessions[sessionID]?.markUnresponsive()
    }
}
