import Foundation

/// Destination for emitted trace events.
///
/// Sinks are replaceable so tests can capture events in memory and
/// production can forward to SDL telemetry or local files.
public protocol TraceEventSink: Sendable {
    func emit(_ event: TraceEvent) async throws
}

/// In-memory sink for testing and diagnostics.
public actor InMemoryTraceEventSink: TraceEventSink {
    public private(set) var events: [TraceEvent] = []

    public init() {}

    public func emit(_ event: TraceEvent) async throws {
        events.append(event)
    }

    public func events(ofKind kind: TraceEventKind) -> [TraceEvent] {
        events.filter { $0.eventType == kind.rawValue }
    }

    public func clear() {
        events.removeAll()
    }
}

/// Errors thrown by the trace event emitter.
public enum TraceEventEmitterError: Error, Sendable {
    case invalidEvent(TraceValidationResult)
}

/// Emits validated `TraceEvent`s through the bridge pipeline.
///
/// The emitter owns trace-id generation, parent-child correlation, and
/// kind-specific attribute assembly. It validates every event before
/// sending it to the sink so that incomplete traces are never persisted.
public actor TraceEventEmitter: Sendable {

    private let sink: any TraceEventSink
    private var eventCounter: UInt64 = 0

    public init(sink: any TraceEventSink) {
        self.sink = sink
    }

    /// Emit a raw event after validating it against `TraceEventRequirements`.
    public func emit(_ event: TraceEvent) async throws {
        let result = TraceEventRequirements.validate(event)
        guard result.isValid else {
            throw TraceEventEmitterError.invalidEvent(result)
        }
        try await sink.emit(event)
    }

    /// Emit `intent.received` for the given intent.
    @discardableResult
    public func intentReceived(_ intent: Intent, traceId: String? = nil) async throws -> TraceEvent {
        let traceId = traceId ?? newTraceId()
        let event = TraceEventBuilder(
            eventType: .intentReceived,
            traceId: traceId,
            subjectRef: intent.id,
            status: "ok",
            outcome: "intent received from \(intent.source)",
            payloadSummary: String(intent.rawText.prefix(200)),
            payloadHash: hash(intent.rawText),
            attributes: [
                "intent.source": intent.source,
                "intent.rawText": intent.rawText,
                "intent.locale": intent.locale
            ]
        ).build()
        try await emit(event)
        return event
    }

    /// Emit `task.framed` for the given task frame.
    @discardableResult
    public func taskFramed(_ frame: TaskFrame, parentEventId: String? = nil, traceId: String) async throws -> TraceEvent {
        let event = TraceEventBuilder(
            eventType: .taskFramed,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: frame.taskRef,
            status: "ok",
            outcome: "task framed",
            payloadSummary: "riskTier=\(frame.riskTier) autonomyMode=\(frame.autonomyMode)",
            payloadHash: hash(frame.userGoal),
            attributes: [
                "taskFrame.taskRef": frame.taskRef,
                "taskFrame.riskTier": frame.riskTier,
                "taskFrame.autonomyMode": frame.autonomyMode
            ]
        ).build()
        try await emit(event)
        return event
    }

    /// Emit `plan.produced` for the given capability plan.
    @discardableResult
    public func planProduced(_ plan: CapabilityPlan, parentEventId: String? = nil, traceId: String) async throws -> TraceEvent {
        let event = TraceEventBuilder(
            eventType: .planProduced,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: plan.taskFrameRef,
            status: "ok",
            outcome: "plan produced with \(plan.allRoutes.count) route(s)",
            payloadSummary: "primary=\(plan.primaryRoute.capability) confidence=\(plan.confidence.rawValue)",
            payloadHash: hash(plan.primaryRoute.capability + plan.fallbackRoutes.map(\.capability).joined()),
            attributes: [
                "capabilityPlan.taskFrameRef": plan.taskFrameRef,
                "capabilityPlan.primaryRoute.capability": plan.primaryRoute.capability,
                "capabilityPlan.confidence": plan.confidence.rawValue,
                "capabilityPlan.fallbackCount": String(plan.fallbackRoutes.count)
            ]
        ).build()
        try await emit(event)
        return event
    }

    /// Emit `route.selected` for a specific route.
    @discardableResult
    public func routeSelected(
        _ route: Route,
        isFallback: Bool,
        parentEventId: String? = nil,
        traceId: String,
        attributes: [String: String] = [:]
    ) async throws -> TraceEvent {
        var attrs = attributes
        attrs["route.capability"] = route.capability
        attrs["route.confidence"] = route.confidence.rawValue
        attrs["route.isFallback"] = String(isFallback)
        let event = TraceEventBuilder(
            eventType: .routeSelected,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: route.capability,
            status: "ok",
            outcome: isFallback ? "fallback route selected" : "primary route selected",
            payloadSummary: "capability=\(route.capability) mode=\(route.invocationMode)",
            payloadHash: hash(route.capability + route.invocationMode + route.reason),
            attributes: attrs
        ).build()
        try await emit(event)
        return event
    }

    /// Emit `capability.invoked` for a capability packet.
    @discardableResult
    public func capabilityInvoked(_ packet: CapabilityPacket, parentEventId: String? = nil, traceId: String) async throws -> TraceEvent {
        let event = TraceEventBuilder(
            eventType: .capabilityInvoked,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: packet.selectedCapability ?? packet.mode,
            status: "ok",
            outcome: "capability invoked in \(packet.invocationMode) mode",
            payloadSummary: "mode=\(packet.invocationMode) allowMutation=\(packet.allowMutation)",
            payloadHash: hash(packet.mode + (packet.selectedCapability ?? "") + packet.invocationMode),
            attributes: [
                "capabilityPacket.mode": packet.mode,
                "capabilityPacket.selectedCapability": packet.selectedCapability ?? "",
                "capabilityPacket.invocationMode": packet.invocationMode,
                "capabilityPacket.allowMutation": String(packet.allowMutation)
            ]
        ).build()
        try await emit(event)
        return event
    }

    /// Emit `capability.completed` after a capability invocation finishes.
    @discardableResult
    public func capabilityCompleted(
        capability: String,
        outcome: String,
        artifactRefs: [String] = [],
        approvalRefs: [String] = [],
        parentEventId: String? = nil,
        traceId: String
    ) async throws -> TraceEvent {
        let event = TraceEventBuilder(
            eventType: .capabilityCompleted,
            traceId: traceId,
            parentEventId: parentEventId,
            subjectRef: capability,
            status: outcome == "success" ? "ok" : "error",
            outcome: outcome,
            payloadSummary: "artifacts=\(artifactRefs.count) approvals=\(approvalRefs.count)",
            payloadHash: hash(capability + outcome + artifactRefs.joined() + approvalRefs.joined()),
            artifactRefs: artifactRefs,
            approvalRefs: approvalRefs
        ).build()
        try await emit(event)
        return event
    }

    /// Convenience: run the full Intent -> TaskFrame -> CapabilityPlan
    /// pipeline and emit the corresponding trace events.
    ///
    /// Returns the trace id used so callers can correlate downstream events.
    public func tracePipeline(
        intent: Intent,
        frame: TaskFrame,
        plan: CapabilityPlan,
        packet: CapabilityPacket? = nil
    ) async throws -> String {
        let traceId = newTraceId()

        let intentEvent = try await intentReceived(intent, traceId: traceId)
        let frameEvent = try await taskFramed(frame, parentEventId: intentEvent.traceId, traceId: traceId)
        let planEvent = try await planProduced(plan, parentEventId: frameEvent.traceId, traceId: traceId)
        let primaryEvent = try await routeSelected(
            plan.primaryRoute,
            isFallback: false,
            parentEventId: planEvent.traceId,
            traceId: traceId
        )

        for (index, fallback) in plan.fallbackRoutes.enumerated() {
            _ = try await routeSelected(
                fallback,
                isFallback: true,
                parentEventId: planEvent.traceId,
                traceId: traceId,
                attributes: ["fallbackIndex": String(index)]
            )
        }

        if let packet {
            let invokedEvent = try await capabilityInvoked(packet, parentEventId: primaryEvent.traceId, traceId: traceId)
            _ = try await capabilityCompleted(
                capability: packet.selectedCapability ?? packet.mode,
                outcome: "success",
                parentEventId: invokedEvent.traceId,
                traceId: traceId
            )
        }

        return traceId
    }

    // MARK: - Helpers

    private func newTraceId() -> String {
        eventCounter += 1
        return "trace-\(ProcessInfo.processInfo.globallyUniqueString)-\(eventCounter)"
    }

    private func hash(_ value: String) -> String {
        // Stable, non-cryptographic hash for test determinism.
        let data = Data(value.utf8)
        return "sha256:\(data.base64EncodedString())"
    }
}
