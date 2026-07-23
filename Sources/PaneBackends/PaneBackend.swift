import Foundation
import WorkspaceTypes

/// A backend that hosts visible agent sessions.
///
/// Pane backends are deliberately narrow: they spawn sessions, send input,
/// and return typed output chunks. All other orchestration lives in the
/// capability-bridge modules.
public protocol PaneBackend: Sendable {
    /// Spawn a new visible session with the given role and identifier.
    func spawnSession(id: String, role: String, command: String?) async throws -> String

    /// Write a line of input to the session.
    func sendInput(sessionID: String, input: String) async throws

    /// Read the latest output from the session as a typed chunk.
    func readOutput(sessionID: String) async throws -> Chunk

    /// Pause or stop the session.
    func stopSession(sessionID: String) async throws
}
