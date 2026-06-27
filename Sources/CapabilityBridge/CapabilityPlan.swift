import Foundation

/// Confidence level produced by the planner for a route.
///
/// Values are ordered from least to most certain. A confidence below
/// `.medium` always triggers at least one fallback route and requires
/// an approval gate before execution.
public enum RoutingConfidence: String, Sendable, CaseIterable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case certain = "certain"

    /// Returns `true` when the confidence is high enough to execute
    /// without human approval under normal policy.
    public var isExecutableWithoutApproval: Bool {
        self == .high || self == .certain
    }

    /// Returns `true` when the confidence is too low to select any
    /// route without human escalation.
    public var requiresEscalation: Bool {
        self == .none || self == .low
    }
}

/// A single candidate route in a capability plan.
public struct Route: Sendable {
    public var capability: String
    public var invocationMode: String
    public var reason: String
    public var confidence: RoutingConfidence

    public init(
        capability: String,
        invocationMode: String = "dry-run",
        reason: String,
        confidence: RoutingConfidence
    ) {
        self.capability = capability
        self.invocationMode = invocationMode
        self.reason = reason
        self.confidence = confidence
    }
}

/// The result of translating a `TaskFrame` into one or more SDL capability
/// routes, including confidence, fallbacks, and authority requirements.
///
/// A `CapabilityPlan` is immutable after construction and is the bridge's
/// primary output to the SDL orchestration layer.
public struct CapabilityPlan: Sendable {
    public let taskFrameRef: String
    public let primaryRoute: Route
    public let fallbackRoutes: [Route]
    public let authorityRequired: [String]
    public let tracePolicy: String
    public let estimatedRiskTier: String

    public init(
        taskFrameRef: String,
        primaryRoute: Route,
        fallbackRoutes: [Route] = [],
        authorityRequired: [String] = [],
        tracePolicy: String = "emit-all",
        estimatedRiskTier: String = "low"
    ) {
        self.taskFrameRef = taskFrameRef
        self.primaryRoute = primaryRoute
        self.fallbackRoutes = fallbackRoutes
        self.authorityRequired = authorityRequired
        self.tracePolicy = tracePolicy
        self.estimatedRiskTier = estimatedRiskTier
    }

    /// The overall confidence of the plan, taken from the primary route.
    public var confidence: RoutingConfidence {
        primaryRoute.confidence
    }

    /// All routes in priority order: primary first, then fallbacks.
    public var allRoutes: [Route] {
        [primaryRoute] + fallbackRoutes
    }

    /// Returns `true` if the plan includes at least one fallback route.
    public var hasFallbacks: Bool {
        !fallbackRoutes.isEmpty
    }
}
