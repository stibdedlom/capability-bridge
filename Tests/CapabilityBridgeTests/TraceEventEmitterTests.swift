import Testing
@testable import CapabilityBridge

@Suite("Trace event emitter")
struct TraceEventEmitterTests {

    @Test("Emitter validates events before sending to sink")
    func validationBlocksInvalidEvents() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)

        let invalid = TraceEventBuilder(
            eventType: .taskFramed,
            traceId: "trace-1",
            subjectRef: "task-1",
            status: "ok",
            outcome: "framed",
            payloadSummary: "summary",
            payloadHash: "sha256:abc",
            attributes: [:]  // missing required taskFrame fields
        ).build()

        await #expect(throws: TraceEventEmitterError.self) {
            try await emitter.emit(invalid)
        }

        let events = await sink.events
        #expect(events.isEmpty)
    }

    @Test("Emitter records intent.received with required attributes")
    func intentReceivedEvent() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let intent = Intent(id: "intent-1", source: "voice", rawText: "Run tests")

        let event = try await emitter.intentReceived(intent)

        #expect(event.eventType == TraceEventKind.intentReceived.rawValue)
        #expect(event.subjectRef == "intent-1")
        #expect(event.attributes["intent.source"] == "voice")
        #expect(event.attributes["intent.rawText"] == "Run tests")

        let events = await sink.events(ofKind: .intentReceived)
        #expect(events.count == 1)
    }

    @Test("Pipeline trace emits all expected event kinds")
    func pipelineTrace() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)

        let intent = Intent(id: "intent-2", source: "text", rawText: "Implement feature")
        let frame = TaskFrame(taskRef: "task-2", userGoal: "Implement feature", sourceIntent: "text")
        let plan = CapabilityPlan(
            taskFrameRef: "task-2",
            primaryRoute: Route(capability: "capability-session-orchestrator", invocationMode: "execute", reason: "Impl", confidence: .high),
            fallbackRoutes: [
                Route(capability: "capability-workflow-router", invocationMode: "dry-run", reason: "Fallback", confidence: .medium)
            ],
            authorityRequired: ["allow_mutation"],
            estimatedRiskTier: "medium"
        )
        let packet = CapabilityPacket(
            mode: "execute",
            selectedCapability: "capability-session-orchestrator",
            invocationMode: "execute",
            contextBundleRef: "bundle-1",
            authorityScope: ["allow_mutation"],
            allowMutation: true,
            expectedOutputs: ["artifactSummary"]
        )

        let traceId = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan, packet: packet)

        let events = await sink.events
        #expect(events.allSatisfy { $0.traceId == traceId })

        #expect(await sink.events(ofKind: .intentReceived).count == 1)
        #expect(await sink.events(ofKind: .taskFramed).count == 1)
        #expect(await sink.events(ofKind: .planProduced).count == 1)
        #expect(await sink.events(ofKind: .routeSelected).count == 2)
        #expect(await sink.events(ofKind: .capabilityInvoked).count == 1)
        #expect(await sink.events(ofKind: .capabilityCompleted).count == 1)
    }

    @Test("Pipeline trace without packet omits capability events")
    func pipelineTraceWithoutPacket() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)

        let intent = Intent(id: "intent-3", source: "tap", rawText: "Plan only")
        let frame = TaskFrame(taskRef: "task-3", userGoal: "Plan only", sourceIntent: "tap")
        let plan = CapabilityPlan(
            taskFrameRef: "task-3",
            primaryRoute: Route(capability: "capability-workflow-router", invocationMode: "dry-run", reason: "Plan", confidence: .high),
            estimatedRiskTier: "low"
        )

        _ = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan, packet: nil)

        #expect(await sink.events(ofKind: .capabilityInvoked).isEmpty)
        #expect(await sink.events(ofKind: .capabilityCompleted).isEmpty)
    }

    @Test("Trace events share the same trace id")
    func sharedTraceId() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)

        let intent = Intent(id: "intent-4", source: "voice", rawText: "Review")
        let frame = TaskFrame(taskRef: "task-4", userGoal: "Review", sourceIntent: "voice")
        let plan = CapabilityPlan(
            taskFrameRef: "task-4",
            primaryRoute: Route(capability: "capability-implementation-reviewer", invocationMode: "dry-run", reason: "Review", confidence: .high),
            estimatedRiskTier: "low"
        )

        let traceId = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan)
        let events = await sink.events

        for event in events {
            #expect(event.traceId == traceId)
        }
    }
}
