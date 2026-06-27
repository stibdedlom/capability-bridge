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

        let result = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan, packet: packet)

        let events = await sink.events
        #expect(events.allSatisfy { $0.traceId == result.traceId })

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

        let result = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan)
        let events = await sink.events

        for event in events {
            #expect(event.traceId == result.traceId)
        }
    }

    @Test("Each trace event has a unique event id and parent-child links form a tree")
    func uniqueEventIdsAndParentLinks() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)

        let intent = Intent(id: "intent-5", source: "voice", rawText: "Run tests")
        let frame = TaskFrame(taskRef: "task-5", userGoal: "Run tests", sourceIntent: "voice")
        let plan = CapabilityPlan(
            taskFrameRef: "task-5",
            primaryRoute: Route(capability: "capability-session-orchestrator", invocationMode: "execute", reason: "Test", confidence: .high),
            estimatedRiskTier: "low"
        )

        let result = try await emitter.tracePipeline(intent: intent, frame: frame, plan: plan)
        let events = await sink.events

        var eventIDs: Set<String> = []
        for event in events {
            #expect(event.eventID.isEmpty == false)
            #expect(eventIDs.insert(event.eventID).inserted)
        }

        let intentEvent = events.first { $0.eventType == TraceEventKind.intentReceived.rawValue }
        let frameEvent = events.first { $0.eventType == TraceEventKind.taskFramed.rawValue }
        #expect(intentEvent != nil)
        #expect(frameEvent != nil)
        #expect(frameEvent?.parentEventID == intentEvent?.eventID)
        #expect(result.intentEventID == intentEvent?.eventID)
    }

    @Test("payloadHash is a real SHA-256 hex digest")
    func realPayloadHash() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let intent = Intent(id: "intent-6", source: "text", rawText: "Hello")

        _ = try await emitter.intentReceived(intent)

        let event = await sink.events.first
        #expect(event != nil)
        #expect(event?.payloadHash.hasPrefix("sha256:") == true)
        if let event {
            let hex = String(event.payloadHash.dropFirst(7))
            #expect(hex.count == 64)
            #expect(hex.allSatisfy { $0.isHexDigit })
        }
    }
}
