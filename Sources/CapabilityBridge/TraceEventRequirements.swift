import Foundation

/// Well-known event kinds for bridge trace events.
///
/// These kinds correspond to the decision points the bridge must record
/// so that every Intent -> TaskFrame -> CapabilityPlan translation is
/// auditable and resumable.
public enum TraceEventKind: String, Sendable, CaseIterable {
    /// An intent was received from COG.
    case intentReceived = "intent.received"

    /// A TaskFrame was produced from an intent.
    case taskFramed = "task.framed"

    /// A CapabilityPlan was produced for a TaskFrame.
    case planProduced = "plan.produced"

    /// A route was selected (primary or fallback).
    case routeSelected = "route.selected"

    /// An approval gate was entered.
    case approvalRequested = "approval.requested"

    /// An approval gate was resolved.
    case approvalResolved = "approval.resolved"

    /// A capability was invoked.
    case capabilityInvoked = "capability.invoked"

    /// A capability invocation completed.
    case capabilityCompleted = "capability.completed"

    /// A trace or audit error occurred.
    case traceError = "trace.error"
}

/// Validation rule for a required trace-event field.
public struct TraceRequirement: Sendable {
    public var field: String
    public var required: Bool
    public var allowedEmpty: Bool

    public init(field: String, required: Bool, allowedEmpty: Bool = false) {
        self.field = field
        self.required = required
        self.allowedEmpty = allowedEmpty
    }
}

/// Phase 1 trace-event requirements.
///
/// Every `TraceEvent` emitted by the bridge must satisfy the requirements
/// for its kind. The validator is intentionally strict: a missing required
/// field fails validation so that incomplete traces cannot be silently
/// promoted into lifecycle records.
public struct TraceEventRequirements: Sendable {

    /// Requirements that apply to every trace event regardless of kind.
    public static var base: [TraceRequirement] {
        [
            TraceRequirement(field: "eventType", required: true),
            TraceRequirement(field: "traceId", required: true),
            TraceRequirement(field: "subjectRef", required: true),
            TraceRequirement(field: "status", required: true),
            TraceRequirement(field: "outcome", required: true),
            TraceRequirement(field: "payloadSummary", required: true),
            TraceRequirement(field: "payloadHash", required: true)
        ]
    }

    /// Requirements specific to a given event kind.
    public static func requirements(for kind: TraceEventKind) -> [TraceRequirement] {
        switch kind {
        case .intentReceived:
            return base + [
                TraceRequirement(field: "intent.source", required: true),
                TraceRequirement(field: "intent.rawText", required: true)
            ]
        case .taskFramed:
            return base + [
                TraceRequirement(field: "taskFrame.taskRef", required: true),
                TraceRequirement(field: "taskFrame.riskTier", required: true),
                TraceRequirement(field: "taskFrame.autonomyMode", required: true)
            ]
        case .planProduced:
            return base + [
                TraceRequirement(field: "capabilityPlan.taskFrameRef", required: true),
                TraceRequirement(field: "capabilityPlan.primaryRoute.capability", required: true),
                TraceRequirement(field: "capabilityPlan.confidence", required: true),
                TraceRequirement(field: "capabilityPlan.fallbackCount", required: true)
            ]
        case .routeSelected:
            return base + [
                TraceRequirement(field: "route.capability", required: true),
                TraceRequirement(field: "route.confidence", required: true),
                TraceRequirement(field: "route.isFallback", required: true)
            ]
        case .approvalRequested, .approvalResolved:
            return base + [
                TraceRequirement(field: "approvalRequest.riskTier", required: true),
                TraceRequirement(field: "approvalRequest.requestedAction", required: true),
                TraceRequirement(field: "approvalRequest.scope", required: true),
                TraceRequirement(field: "approvalRequest.approvalState", required: true)
            ]
        case .capabilityInvoked:
            return base + [
                TraceRequirement(field: "capabilityPacket.mode", required: true),
                TraceRequirement(field: "capabilityPacket.selectedCapability", required: true),
                TraceRequirement(field: "capabilityPacket.invocationMode", required: true),
                TraceRequirement(field: "capabilityPacket.allowMutation", required: true)
            ]
        case .capabilityCompleted:
            return base + [
                TraceRequirement(field: "artifactRefs", required: true, allowedEmpty: true),
                TraceRequirement(field: "approvalRefs", required: true, allowedEmpty: true)
            ]
        case .traceError:
            return base + [
                TraceRequirement(field: "error.message", required: true)
            ]
        }
    }

    /// Validate a trace event against the requirements for its kind.
    ///
    /// Returns `.valid` if all required fields are present and non-empty
    /// (when empty values are disallowed). Returns `.invalid` with a list
    /// of missing or empty fields otherwise.
    ///
    /// Kind-specific fields are read from `event.attributes` using the
    /// requirement's `field` name. Top-level fields are read directly from
    /// the event.
    public static func validate(_ event: TraceEvent) -> TraceValidationResult {
        guard let kind = TraceEventKind(rawValue: event.eventType) else {
            return .invalid(["unrecognized eventType '\(event.eventType)'"])
        }

        var violations: [String] = []
        let reqs = requirements(for: kind)

        for req in reqs where req.required {
            let value = fieldValue(event, fieldPath: req.field)
            if value == nil {
                violations.append("missing '\(req.field)'")
            } else if !req.allowedEmpty && value?.isEmpty == true {
                violations.append("empty '\(req.field)'")
            }
        }

        return violations.isEmpty ? .valid : .invalid(violations)
    }

    private static func fieldValue(_ event: TraceEvent, fieldPath: String) -> String? {
        switch fieldPath {
        case "eventType": return event.eventType
        case "traceId": return event.traceId
        case "subjectRef": return event.subjectRef
        case "status": return event.status
        case "outcome": return event.outcome
        case "payloadSummary": return event.payloadSummary
        case "payloadHash": return event.payloadHash
        case "artifactRefs": return event.artifactRefs.joined(separator: ",")
        case "approvalRefs": return event.approvalRefs.joined(separator: ",")
        default: return event.attributes[fieldPath]
        }
    }
}

/// Result of validating a trace event.
public enum TraceValidationResult: Sendable {
    case valid
    case invalid([String])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var violations: [String] {
        if case .invalid(let v) = self { return v }
        return []
    }
}

/// Convenience builder for bridge trace events.
///
/// The builder enforces required fields by construction and produces a
/// `TraceEvent` that can be validated with `TraceEventRequirements`.
public struct TraceEventBuilder: Sendable {
    public var eventType: TraceEventKind
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
        eventType: TraceEventKind,
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

    public func build() -> TraceEvent {
        TraceEvent(
            eventType: eventType.rawValue,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: subjectRef,
            status: status,
            outcome: outcome,
            payloadSummary: payloadSummary,
            payloadHash: payloadHash,
            artifactRefs: artifactRefs,
            approvalRefs: approvalRefs,
            attributes: attributes
        )
    }
}
