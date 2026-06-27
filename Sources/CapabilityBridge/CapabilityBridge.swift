/// Capability Bridge core protocols and types.
///
/// This module defines the language-agnostic contracts that are also
/// expressed as JSON Schema in `spec/`. Concrete adapters for COG, SDL,
/// pane backends, approval surfaces, and model routers live in separate
/// modules so they can be replaced without changing the core.

import Foundation

// MARK: - Enumerated schema fields

/// Estimated risk tier of a task or requested action.
public enum RiskTier: String, Sendable, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Requested autonomy level for a task.
public enum AutonomyMode: String, Sendable, Codable, CaseIterable {
    case advise = "advise"
    case plan = "plan"
    case execute = "execute"
}

/// Lifecycle status of a task frame.
public enum TaskFrameStatus: String, Sendable, Codable, CaseIterable {
    case new = "new"
    case framed = "framed"
    case planned = "planned"
    case approved = "approved"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Current state of an approval request or response.
public enum ApprovalState: String, Sendable, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case denied = "denied"
    case expired = "expired"
}

/// Whether a capability invocation should actually mutate state.
public enum InvocationMode: String, Sendable, Codable, CaseIterable {
    case dryRun = "dry-run"
    case execute = "execute"
}

/// A scoped, routeable unit of work produced from a COG Intent.
public struct TaskFrame: Sendable, Codable, Equatable {
    public let taskRef: String
    public let userGoal: String
    public let sourceIntent: String
    public let workspaceTarget: String?
    public let repoContext: String?
    public let riskTier: RiskTier
    public let autonomyMode: AutonomyMode
    public let requestedOutcome: String
    public let constraints: [String]
    public let status: TaskFrameStatus
    public let openQuestions: [String]

    public init(
        taskRef: String,
        userGoal: String,
        sourceIntent: String,
        workspaceTarget: String? = nil,
        repoContext: String? = nil,
        riskTier: RiskTier = .low,
        autonomyMode: AutonomyMode = .advise,
        requestedOutcome: String = "",
        constraints: [String] = [],
        status: TaskFrameStatus = .new,
        openQuestions: [String] = []
    ) {
        self.taskRef = taskRef
        self.userGoal = userGoal
        self.sourceIntent = sourceIntent
        self.workspaceTarget = workspaceTarget
        self.repoContext = repoContext
        self.riskTier = riskTier
        self.autonomyMode = autonomyMode
        self.requestedOutcome = requestedOutcome
        self.constraints = constraints
        self.status = status
        self.openQuestions = openQuestions
    }

    enum CodingKeys: String, CodingKey {
        case taskRef
        case userGoal
        case sourceIntent
        case workspaceTarget
        case repoContext
        case riskTier
        case autonomyMode
        case requestedOutcome
        case constraints
        case status
        case openQuestions
    }
}

/// A bounded context package with provenance.
public struct ContextBundle: Sendable, Codable, Equatable {
    public let workspaceSnapshot: String?
    public let noteRefs: [String]
    public let memorySnippets: [String]
    public let artifactRefs: [String]
    public let auraRefs: [String]
    public let omissions: [String]
    public let freshness: Date
    public let tokenBudget: Int
    public let rawContentPolicy: String

    public init(
        workspaceSnapshot: String? = nil,
        noteRefs: [String] = [],
        memorySnippets: [String] = [],
        artifactRefs: [String] = [],
        auraRefs: [String] = [],
        omissions: [String] = [],
        freshness: Date = Date(),
        tokenBudget: Int = 4096,
        rawContentPolicy: String = "redact-sensitive"
    ) {
        self.workspaceSnapshot = workspaceSnapshot
        self.noteRefs = noteRefs
        self.memorySnippets = memorySnippets
        self.artifactRefs = artifactRefs
        self.auraRefs = auraRefs
        self.omissions = omissions
        self.freshness = freshness
        self.tokenBudget = tokenBudget
        self.rawContentPolicy = rawContentPolicy
    }

    enum CodingKeys: String, CodingKey {
        case workspaceSnapshot
        case noteRefs
        case memorySnippets
        case artifactRefs
        case auraRefs = "aurRefs"
        case omissions
        case freshness
        case tokenBudget
        case rawContentPolicy
    }
}

/// A request from the bridge to the SDL capability layer.
public struct CapabilityPacket: Sendable, Codable, Equatable {
    public let mode: String
    public let selectedCapability: String?
    public let invocationMode: InvocationMode
    public let inputs: [String: String]
    public let contextBundleRef: String
    public let authorityScope: [String]
    public let allowMutation: Bool
    public let expectedOutputs: [String]

    public init(
        mode: String,
        selectedCapability: String? = nil,
        invocationMode: InvocationMode = .dryRun,
        inputs: [String: String] = [:],
        contextBundleRef: String,
        authorityScope: [String] = [],
        allowMutation: Bool = false,
        expectedOutputs: [String] = []
    ) {
        self.mode = mode
        self.selectedCapability = selectedCapability
        self.invocationMode = invocationMode
        self.inputs = inputs
        self.contextBundleRef = contextBundleRef
        self.authorityScope = authorityScope
        self.allowMutation = allowMutation
        self.expectedOutputs = expectedOutputs
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case selectedCapability
        case invocationMode
        case inputs
        case contextBundleRef
        case authorityScope
        case allowMutation
        case expectedOutputs
    }
}

/// A human decision envelope for risky actions.
public struct ApprovalRequest: Sendable, Codable, Equatable {
    public let riskTier: RiskTier
    public let requestedAction: String
    public let evidenceRefs: [String]
    public let scope: String
    public let expiresAt: Date?
    public let prohibitedActions: [String]
    public let confirmationRitual: String
    public let approvalState: ApprovalState

    public init(
        riskTier: RiskTier,
        requestedAction: String,
        evidenceRefs: [String] = [],
        scope: String,
        expiresAt: Date? = nil,
        prohibitedActions: [String] = [],
        confirmationRitual: String = "tap-approve",
        approvalState: ApprovalState = .pending
    ) {
        self.riskTier = riskTier
        self.requestedAction = requestedAction
        self.evidenceRefs = evidenceRefs
        self.scope = scope
        self.expiresAt = expiresAt
        self.prohibitedActions = prohibitedActions
        self.confirmationRitual = confirmationRitual
        self.approvalState = approvalState
    }

    enum CodingKeys: String, CodingKey {
        case riskTier
        case requestedAction
        case evidenceRefs
        case scope
        case expiresAt
        case prohibitedActions
        case confirmationRitual
        case approvalState
    }
}

/// An append-only correlation record.
public struct TraceEvent: Sendable, Codable, Equatable {
    public let eventID: String
    public let eventType: String
    public let traceId: String
    public let parentEventID: String?
    public let subjectRef: String
    public let status: String
    public let outcome: String
    public let payloadSummary: String
    public let payloadHash: String
    public let artifactRefs: [String]
    public let approvalRefs: [String]
    public let attributes: [String: String]

    public init(
        eventID: String,
        eventType: String,
        traceId: String,
        parentEventID: String? = nil,
        subjectRef: String,
        status: String,
        outcome: String,
        payloadSummary: String,
        payloadHash: String,
        artifactRefs: [String] = [],
        approvalRefs: [String] = [],
        attributes: [String: String] = [:]
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.traceId = traceId
        self.parentEventID = parentEventID
        self.subjectRef = subjectRef
        self.status = status
        self.outcome = outcome
        self.payloadSummary = payloadSummary
        self.payloadHash = payloadHash
        self.artifactRefs = artifactRefs
        self.approvalRefs = approvalRefs
        self.attributes = attributes
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "eventId"
        case eventType
        case traceId
        case parentEventID = "parentEventId"
        case subjectRef
        case status
        case outcome
        case payloadSummary
        case payloadHash
        case artifactRefs
        case approvalRefs
        case attributes
    }
}

/// A compact result for user display and deeper linking.
public struct ArtifactSummary: Sendable, Codable, Equatable {
    public let artifactRef: String
    public let artifactType: String
    public let pathOrURI: String
    public let fingerprint: String
    public let producerCapability: String
    public let title: String
    public let summary: String
    public let conformanceSummary: String
    public let redactionState: String

    public init(
        artifactRef: String,
        artifactType: String,
        pathOrURI: String,
        fingerprint: String,
        producerCapability: String,
        title: String,
        summary: String,
        conformanceSummary: String = "",
        redactionState: String = "none"
    ) {
        self.artifactRef = artifactRef
        self.artifactType = artifactType
        self.pathOrURI = pathOrURI
        self.fingerprint = fingerprint
        self.producerCapability = producerCapability
        self.title = title
        self.summary = summary
        self.conformanceSummary = conformanceSummary
        self.redactionState = redactionState
    }

    enum CodingKeys: String, CodingKey {
        case artifactRef
        case artifactType
        case pathOrURI
        case fingerprint
        case producerCapability
        case title
        case summary
        case conformanceSummary
        case redactionState
    }
}

/// Protocol for backends that host visible agent sessions.
public protocol PaneBackend: Sendable {
    /// Spawn a new visible session with the given role and identifier.
    func spawnSession(id: String, role: String, command: String?) async throws -> String

    /// Write a line of input to the session.
    func sendInput(sessionID: String, input: String) async throws

    /// Read the latest output from the session.
    func readOutput(sessionID: String) async throws -> String

    /// Pause or stop the session.
    func stopSession(sessionID: String) async throws
}
