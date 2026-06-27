/// In-memory model of a single visible session.

import CapabilityBridge
import Foundation

/// Mutable session state held by a backend.
public struct PaneSession: Sendable, Identifiable, Equatable {
    public let id: String
    public let role: String
    public let command: String?
    public let backendID: String
    public private(set) var status: PaneSessionStatus
    public private(set) var output: [String]
    public private(set) var pendingInput: [String]

    public init(
        id: String,
        role: String,
        command: String?,
        backendID: String,
        status: PaneSessionStatus = .spawning
    ) {
        self.id = id
        self.role = role
        self.command = command
        self.backendID = backendID
        self.status = status
        self.output = []
        self.pendingInput = []
    }

    public var summary: PaneSessionSummary {
        PaneSessionSummary(
            id: id,
            role: role,
            status: status,
            command: command,
            backendID: backendID
        )
    }

    public mutating func markRunning() {
        status = .running
    }

    public mutating func markStopped() {
        status = .stopped
    }

    public mutating func markError() {
        status = .error
    }

    public mutating func markUnresponsive() {
        status = .unresponsive
    }

    public mutating func appendOutput(_ line: String) {
        output.append(line)
    }

    public mutating func enqueueInput(_ line: String) {
        pendingInput.append(line)
    }

    public mutating func clearPendingInput() -> [String] {
        let lines = pendingInput
        pendingInput = []
        return lines
    }
}
