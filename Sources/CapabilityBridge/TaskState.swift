import Foundation
import WorkspaceTypes

// MARK: - Task Phase

/// The lifecycle phase of a task flowing through the capability bridge.
public enum TaskPhase: String, Sendable, Equatable, CaseIterable {
    case pending
    case planning
    case awaitingApproval
    case executing
    case completed
    case failed
    case stopped
}

// MARK: - Task Checkpoint

/// An immutable record that a task reached a given phase.
public struct TaskCheckpoint: Sendable, Equatable {
    /// The phase that was entered.
    public let phase: TaskPhase

    /// When the checkpoint was recorded (Unix milliseconds).
    public let timestamp: Int

    /// An optional human-readable note.
    public let note: String

    public init(phase: TaskPhase, timestamp: Int, note: String = "") {
        self.phase = phase
        self.timestamp = timestamp
        self.note = note
    }
}

// MARK: - Stop Signal

/// The reason a task was stopped before completion.
public enum StopSignal: String, Sendable, Equatable, CaseIterable {
    case userCancelled
    case policyDenied
    case timeout
    case hostUnavailable
}

// MARK: - Session State

/// Lightweight runtime state for a bridge session.
public struct SessionState: Sendable, Equatable {
    /// The session identifier.
    public var sessionID: String

    /// Task trace identifiers currently active in the session.
    public var activeTaskRefs: [String]

    /// When the session was created (Unix milliseconds).
    public var createdAt: Int

    /// When the session was last updated (Unix milliseconds).
    public var updatedAt: Int

    public init(
        sessionID: String,
        activeTaskRefs: [String] = [],
        createdAt: Int,
        updatedAt: Int? = nil
    ) {
        self.sessionID = sessionID
        self.activeTaskRefs = activeTaskRefs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

// MARK: - Task State

/// The mutable runtime state of a single task as it moves through the bridge.
public struct TaskState: Sendable, Equatable {
    /// The canonical task frame produced from a COG intent and context.
    public var frame: CogTaskFrame

    /// The current lifecycle phase.
    public var phase: TaskPhase

    /// Checkpoints recorded so far, in order.
    public var checkpoints: [TaskCheckpoint]

    /// The session this task belongs to, if any.
    public var sessionID: String?

    /// The reason the task was stopped, if applicable.
    public var stopSignal: StopSignal?

    /// When the task was created (Unix milliseconds).
    public var createdAt: Int

    /// When the task was last updated (Unix milliseconds).
    public var updatedAt: Int

    public init(
        frame: CogTaskFrame,
        phase: TaskPhase = .pending,
        checkpoints: [TaskCheckpoint] = [],
        sessionID: String? = nil,
        stopSignal: StopSignal? = nil,
        createdAt: Int,
        updatedAt: Int? = nil
    ) {
        self.frame = frame
        self.phase = phase
        self.checkpoints = checkpoints
        self.sessionID = sessionID
        self.stopSignal = stopSignal
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Record a new checkpoint and move to the given phase.
    public mutating func transition(to phase: TaskPhase, at timestamp: Int, note: String = "") {
        self.phase = phase
        self.checkpoints.append(TaskCheckpoint(phase: phase, timestamp: timestamp, note: note))
        self.updatedAt = timestamp
    }
}
