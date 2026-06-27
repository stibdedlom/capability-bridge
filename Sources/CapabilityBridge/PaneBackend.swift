/// Types and protocol for visible agent session backends.

import Foundation

/// Lifecycle status of a pane-hosted session.
public enum PaneSessionStatus: String, Sendable, Equatable {
    case spawning
    case running
    case paused
    case stopped
    case unresponsive
    case error
}

/// Errors raised by pane backends.
public enum PaneBackendError: Error, Equatable {
    case sessionNotFound(String)
    case sessionAlreadyExists(String)
    case backendUnavailable
    case spawnFailed(String)
    case stopFailed(String)
    case inputFailed(String)
    case outputFailed(String)
}

/// A lightweight summary of a visible session for orchestration and display.
public struct PaneSessionSummary: Sendable, Equatable {
    public let id: String
    public let role: String
    public let status: PaneSessionStatus
    public let command: String?
    public let backendID: String

    public init(
        id: String,
        role: String,
        status: PaneSessionStatus,
        command: String?,
        backendID: String
    ) {
        self.id = id
        self.role = role
        self.status = status
        self.command = command
        self.backendID = backendID
    }
}

/// Protocol for backends that host visible agent sessions.
///
/// Concrete backends (tmux, Zellij, native windows, test mocks) implement this
/// protocol without changing core bridge orchestration logic.
public protocol PaneBackend: Sendable {
    /// Stable identifier for this backend instance.
    var backendID: String { get }

    /// Spawn a new visible session with the given role and identifier.
    /// Returns the session identifier.
    func spawnSession(id: String, role: String, command: String?) async throws -> String

    /// Write a line of input to the session.
    func sendInput(sessionID: String, input: String) async throws

    /// Read the latest output from the session.
    func readOutput(sessionID: String) async throws -> String

    /// Pause or stop the session.
    func stopSession(sessionID: String) async throws

    /// List sessions currently managed by this backend.
    func listSessions() async -> [PaneSessionSummary]
}
