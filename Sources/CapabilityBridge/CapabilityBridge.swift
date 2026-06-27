/// Capability Bridge core protocols and types.
///
/// This module defines the language-agnostic contracts that are also
/// expressed as JSON Schema in `spec/`. Concrete adapters for COG, SDL,
/// pane backends, approval surfaces, and model routers live in separate
/// modules so they can be replaced without changing the core.

import Foundation

/// A scoped, routeable unit of work produced from a COG Intent.
public struct TaskFrame: Sendable {
    public var taskRef: String
    public var userGoal: String
    public var sourceIntent: String
    public var workspaceTarget: String?
    public var repoContext: String?
    public var riskTier: String
    public var autonomyMode: String
    public var requestedOutcome: String
    public var constraints: [String]
    public var status: String
    public var openQuestions: [String]

    public init(
        taskRef: String,
        userGoal: String,
        sourceIntent: String,
        workspaceTarget: String? = nil,
        repoContext: String? = nil,
        riskTier: String = "low",
        autonomyMode: String = "advise",
        requestedOutcome: String = "",
        constraints: [String] = [],
        status: String = "new",
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
}

/// A bounded context package with provenance.
public struct ContextBundle: Sendable {
    public var workspaceSnapshot: String?
    public var noteRefs: [String]
    public var memorySnippets: [String]
    public var artifactRefs: [String]
    public var aurRefs: [String]
    public var omissions: [String]
    public var freshness: Date
    public var tokenBudget: Int
    public var rawContentPolicy: String

    public init(
        workspaceSnapshot: String? = nil,
        noteRefs: [String] = [],
        memorySnippets: [String] = [],
        artifactRefs: [String] = [],
        aurRefs: [String] = [],
        omissions: [String] = [],
        freshness: Date = Date(),
        tokenBudget: Int = 4096,
        rawContentPolicy: String = "redact-sensitive"
    ) {
        self.workspaceSnapshot = workspaceSnapshot
        self.noteRefs = noteRefs
        self.memorySnippets = memorySnippets
        self.artifactRefs = artifactRefs
        self.aurRefs = aurRefs
        self.omissions = omissions
        self.freshness = freshness
        self.tokenBudget = tokenBudget
        self.rawContentPolicy = rawContentPolicy
    }
}

/// A request from the bridge to the SDL capability layer.
public struct CapabilityPacket: Sendable {
    public var mode: String
    public var selectedCapability: String?
    public var invocationMode: String
    public var inputs: [String: String]
    public var contextBundleRef: String
    public var authorityScope: [String]
    public var allowMutation: Bool
    public var expectedOutputs: [String]

    public init(
        mode: String,
        selectedCapability: String? = nil,
        invocationMode: String = "dry-run",
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
}

/// A human decision envelope for risky actions.
public struct ApprovalRequest: Sendable {
    public var riskTier: String
    public var requestedAction: String
    public var evidenceRefs: [String]
    public var scope: String
    public var expiresAt: Date?
    public var prohibitedActions: [String]
    public var confirmationRitual: String
    public var approvalState: String

    public init(
        riskTier: String,
        requestedAction: String,
        evidenceRefs: [String] = [],
        scope: String,
        expiresAt: Date? = nil,
        prohibitedActions: [String] = [],
        confirmationRitual: String = "tap-approve",
        approvalState: String = "pending"
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
}

/// An append-only correlation record.
public struct TraceEvent: Sendable {
    public var eventType: String
    public var traceId: String
    public var parentEventId: String?
    public var subjectRef: String
    public var status: String
    public var outcome: String
    public var payloadSummary: String
    public var payloadHash: String
    public var artifactRefs: [String]
    public var approvalRefs: [String]
    public var attributes: [String: String]

    public init(
        eventType: String,
        traceId: String,
        parentEventId: String? = nil,
        subjectRef: String,
        status: String,
        outcome: String,
        payloadSummary: String,
        payloadHash: String,
        artifactRefs: [String] = [],
        approvalRefs: [String] = [],
        attributes: [String: String] = [:]
    ) {
        self.eventType = eventType
        self.traceId = traceId
        self.parentEventId = parentEventId
        self.subjectRef = subjectRef
        self.status = status
        self.outcome = outcome
        self.payloadSummary = payloadSummary
        self.payloadHash = payloadHash
        self.artifactRefs = artifactRefs
        self.approvalRefs = approvalRefs
        self.attributes = attributes
    }
}

/// A compact result for user display and deeper linking.
public struct ArtifactSummary: Sendable {
    public var artifactRef: String
    public var artifactType: String
    public var pathOrURI: String
    public var fingerprint: String
    public var producerCapability: String
    public var title: String
    public var summary: String
    public var conformanceSummary: String
    public var redactionState: String

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
