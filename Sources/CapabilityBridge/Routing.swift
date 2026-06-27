import Foundation

/// Thrown when the planner cannot produce any route for the given intent.
public struct RoutingError: Error, Sendable {
    public var taskFrameRef: String
    public var reason: String

    public init(taskFrameRef: String, reason: String) {
        self.taskFrameRef = taskFrameRef
        self.reason = reason
    }
}

/// Translates `Intent` -> `TaskFrame` -> `CapabilityPlan`.
///
/// Implementations are replaceable; the default keyword-based planner is
/// intended for Phase 1 scaffolding and can be overridden by an SDL-backed
/// router later.
public protocol CapabilityPlanner: Sendable {
    /// Translate a raw intent into a framed task.
    func frame(intent: Intent) async throws -> TaskFrame

    /// Produce a capability plan for the framed task.
    func plan(frame: TaskFrame) async throws -> CapabilityPlan

    /// Convenience: frame then plan.
    func plan(intent: Intent) async throws -> CapabilityPlan
}

extension CapabilityPlanner {
    public func plan(intent: Intent) async throws -> CapabilityPlan {
        try await plan(frame: frame(intent: intent))
    }
}

/// A rule that maps a task-frame signal to a capability route.
struct RoutingRule: Sendable {
    var keywords: [String]
    var capability: String
    var invocationMode: String
    var confidence: RoutingConfidence
    var reason: String
    var authority: [String]
    var riskTier: String
}

/// Phase 1 default planner.
///
/// Uses simple keyword matching against the user goal to demonstrate the
/// Intent -> TaskFrame -> CapabilityPlan contract. It always emits at
/// least one fallback route when confidence is below `.high`, satisfying
/// the Phase 1 fallback requirement.
public struct DefaultCapabilityPlanner: CapabilityPlanner {

    private let rules: [RoutingRule]

    public init() {
        self.rules = DefaultCapabilityPlanner.defaultRules
    }

    init(rules: [RoutingRule]? = nil) {
        self.rules = rules ?? DefaultCapabilityPlanner.defaultRules
    }

    public func frame(intent: Intent) async throws -> TaskFrame {
        TaskFrame(
            taskRef: intent.id,
            userGoal: intent.rawText,
            sourceIntent: intent.source,
            workspaceTarget: intent.metadata["workspaceTarget"],
            repoContext: intent.metadata["repoContext"],
            riskTier: deriveRiskTier(intent: intent),
            autonomyMode: deriveAutonomyMode(intent: intent),
            requestedOutcome: intent.metadata["requestedOutcome"] ?? "",
            constraints: [],
            status: "framed",
            openQuestions: []
        )
    }

    public func plan(frame: TaskFrame) async throws -> CapabilityPlan {
        guard !rules.isEmpty else {
            throw RoutingError(
                taskFrameRef: frame.taskRef,
                reason: "No capability matched intent: \(frame.userGoal)"
            )
        }

        let lowercasedGoal = frame.userGoal.lowercased()

        let scored = rules.compactMap { rule -> (rule: RoutingRule, matches: Int)? in
            let matches = rule.keywords.filter { lowercasedGoal.contains($0) }.count
            guard matches > 0 else { return nil }
            return (rule, matches)
        }.sorted { $0.matches > $1.matches }

        let primaryRule: RoutingRule
        if let top = scored.first {
            primaryRule = top.rule
        } else {
            // No keyword matched, but rules exist: degrade to the workflow router
            // so the request is never silently dropped.
            primaryRule = RoutingRule(
                keywords: [],
                capability: "capability-workflow-router",
                invocationMode: "dry-run",
                confidence: .low,
                reason: "No keyword matched the goal; escalating to workflow router",
                authority: ["approval-gate"],
                riskTier: "low"
            )
        }

        let primary = Route(
            capability: primaryRule.capability,
            invocationMode: primaryRule.invocationMode,
            reason: primaryRule.reason,
            confidence: primaryRule.confidence
        )

        // Fallbacks are the next best distinct-capability routes.
        var seen: Set<String> = [primary.capability]
        var fallbacks: [Route] = []
        for candidate in scored.dropFirst() where !seen.contains(candidate.rule.capability) {
            seen.insert(candidate.rule.capability)
            fallbacks.append(Route(
                capability: candidate.rule.capability,
                invocationMode: candidate.rule.invocationMode,
                reason: candidate.rule.reason,
                confidence: minConfidence(candidate.rule.confidence, .medium)
            ))
        }

        // If confidence is not high/certain, ensure at least one generic
        // fallback exists for graceful degradation.
        if primary.confidence != .high && primary.confidence != .certain && fallbacks.isEmpty {
            fallbacks.append(Route(
                capability: "capability-workflow-router",
                invocationMode: "dry-run",
                reason: "Heuristic fallback when no high-confidence route is available",
                confidence: .medium
            ))
        }

        let authority = deriveAuthority(primary: primaryRule, frame: frame)

        return CapabilityPlan(
            taskFrameRef: frame.taskRef,
            primaryRoute: primary,
            fallbackRoutes: fallbacks,
            authorityRequired: authority,
            tracePolicy: "emit-all",
            estimatedRiskTier: primaryRule.riskTier
        )
    }

    // MARK: - Helpers

    private func deriveRiskTier(intent: Intent) -> String {
        let text = intent.rawText.lowercased()
        if text.contains("delete") || text.contains("remove") || text.contains("drop") {
            return "high"
        }
        if text.contains("edit") || text.contains("change") || text.contains("update") {
            return "medium"
        }
        return "low"
    }

    private func deriveAutonomyMode(intent: Intent) -> String {
        let text = intent.rawText.lowercased()
        if text.contains("just do it") || text.contains("go ahead") {
            return "execute"
        }
        if text.contains("plan") || text.contains("how should") {
            return "plan"
        }
        return "advise"
    }

    private func deriveAuthority(primary: RoutingRule, frame: TaskFrame) -> [String] {
        var authority = primary.authority
        if frame.riskTier == "high" {
            authority.append("approval-gate")
        }
        if primary.invocationMode == "execute" {
            authority.append("allow_mutation")
        }
        return Array(Set(authority)).sorted()
    }

    private func minConfidence(_ a: RoutingConfidence, _ b: RoutingConfidence) -> RoutingConfidence {
        let order: [RoutingConfidence] = [.none, .low, .medium, .high, .certain]
        guard let ai = order.firstIndex(of: a), let bi = order.firstIndex(of: b) else { return b }
        return order[min(ai, bi)]
    }

    // MARK: - Default rules

    private static var defaultRules: [RoutingRule] {
        [
            RoutingRule(
                keywords: ["test", "tests", "verify", "swift test"],
                capability: "capability-session-orchestrator",
                invocationMode: "execute",
                confidence: .high,
                reason: "Goal explicitly requests running Swift tests in an isolated worktree",
                authority: ["branch_or_worktree_isolation", "verification_and_rollback_plan"],
                riskTier: "low"
            ),
            RoutingRule(
                keywords: ["implement", "add", "create", "write", "slice"],
                capability: "capability-session-orchestrator",
                invocationMode: "execute",
                confidence: .high,
                reason: "Goal requests bounded implementation in an isolated worktree",
                authority: ["allow_mutation", "allowed_paths", "branch_or_worktree_isolation", "approval_gate", "verification_and_rollback_plan"],
                riskTier: "medium"
            ),
            RoutingRule(
                keywords: ["review", "check", "audit"],
                capability: "capability-implementation-reviewer",
                invocationMode: "dry-run",
                confidence: .high,
                reason: "Goal asks for review or audit without mutation",
                authority: [],
                riskTier: "low"
            ),
            RoutingRule(
                keywords: ["route", "classify", "which capability"],
                capability: "capability-workflow-router",
                invocationMode: "dry-run",
                confidence: .high,
                reason: "Goal is about routing or capability selection",
                authority: [],
                riskTier: "low"
            ),
            RoutingRule(
                keywords: ["schema", "contract", "spec"],
                capability: "capability-schema-governance",
                invocationMode: "dry-run",
                confidence: .medium,
                reason: "Goal touches language-agnostic schemas",
                authority: ["approval-gate"],
                riskTier: "low"
            )
        ]
    }
}
