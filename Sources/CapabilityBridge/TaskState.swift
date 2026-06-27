/// In-memory task state representation.
///
/// Durable state lives in SDL lifecycle records and trace events (see
/// `docs/decisions/002-durable-task-state.md`). The bridge owns this
/// in-memory representation and the logic to hydrate/dehydrate it.

import Foundation

/// Lifecycle phase of a task frame.
public enum TaskPhase: String, Sendable, Equatable {
    case new
    case routing
    case awaitingApproval
    case executing
    case reviewing
    case checkpoint
    case completed
    case stopped
    case failed
}

/// A checkpoint captured during task execution.
public struct TaskCheckpoint: Sendable, Equatable {
    public let id: String
    public let phase: TaskPhase
    public let timestamp: Date
    public let summary: String
    public let traceRefs: [String]

    public init(
        id: String,
        phase: TaskPhase,
        timestamp: Date = Date(),
        summary: String,
        traceRefs: [String] = []
    ) {
        self.id = id
        self.phase = phase
        self.timestamp = timestamp
        self.summary = summary
        self.traceRefs = traceRefs
    }
}

/// State of a single visible session belonging to a task.
public struct SessionState: Sendable, Equatable {
    public let sessionID: String
    public let role: String
    public let backendID: String
    public let command: String?
    public var status: PaneSessionStatus
    public var lastOutput: String?
    public var lastHealthStatus: SessionHealthStatus?
    public var stopSignal: StopSignal?

    public init(
        sessionID: String,
        role: String,
        backendID: String,
        command: String? = nil,
        status: PaneSessionStatus = .spawning,
        lastOutput: String? = nil,
        lastHealthStatus: SessionHealthStatus? = nil,
        stopSignal: StopSignal? = nil
    ) {
        self.sessionID = sessionID
        self.role = role
        self.backendID = backendID
        self.command = command
        self.status = status
        self.lastOutput = lastOutput
        self.lastHealthStatus = lastHealthStatus
        self.stopSignal = stopSignal
    }
}

/// Signals that can stop or redirect a session.
public enum StopSignal: String, Sendable, Equatable {
    case reviewerRequestedHalt
    case humanRedirected
    case errorThreshold
    case timeBudgetExpired
    case iterationLimitReached
    case healthCheckFailed
}

/// In-memory aggregate state for a single task frame.
public struct TaskState: Sendable, Equatable {
    public let taskRef: String
    public var phase: TaskPhase
    public var frame: TaskFrame
    public var sessions: [String: SessionState]
    public var checkpoints: [TaskCheckpoint]
    public var pendingApprovalRefs: [String]
    public var loopContext: LoopContext?
    public var updatedAt: Date

    public init(
        taskRef: String,
        phase: TaskPhase = .new,
        frame: TaskFrame,
        sessions: [String: SessionState] = [:],
        checkpoints: [TaskCheckpoint] = [],
        pendingApprovalRefs: [String] = [],
        loopContext: LoopContext? = nil,
        updatedAt: Date = Date()
    ) {
        self.taskRef = taskRef
        self.phase = phase
        self.frame = frame
        self.sessions = sessions
        self.checkpoints = checkpoints
        self.pendingApprovalRefs = pendingApprovalRefs
        self.loopContext = loopContext
        self.updatedAt = updatedAt
    }
}
