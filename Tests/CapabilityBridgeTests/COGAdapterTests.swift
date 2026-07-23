import Testing
@testable import CapabilityBridge
@testable import CapabilityBridgeCOG
@testable import CapabilityBridgeSDL

@Suite("COG Adapter")
struct COGAdapterTests {

    private func makeAdapter(includePacket: Bool = true) -> COGAdapter {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        return COGAdapter(
            planner: DefaultCapabilityPlanner(),
            sdlAdapter: SDLAdapter(registryRef: "sdl://registry/test"),
            traceEmitter: emitter,
            includePacketInResult: includePacket
        )
    }

    @Test("COGAdapter handles an intent end-to-end")
    func endToEndIntent() async throws {
        let adapter = makeAdapter()
        let intent = Intent(
            id: "intent-1",
            source: "voice",
            rawText: "Run the tests in an isolated worktree"
        )

        let result = try await adapter.handle(intent: intent)

        #expect(result.status == "ok")
        #expect(result.traceId.isEmpty == false)
        #expect(result.taskFrame.taskRef == "intent-1")
        #expect(result.capabilityPlan.primaryRoute.capability == "capability-session-orchestrator")
        #expect(result.capabilityPacket != nil)
        #expect(result.capabilityPacket?.allowMutation == true)
        #expect(result.contextBundleRef?.hasPrefix("context-bundle:") == true)
        #expect(result.summary.contains("voice"))
    }

    @Test("COGAdapter can omit packet from result")
    func omitPacket() async throws {
        let adapter = makeAdapter(includePacket: false)
        let intent = Intent(id: "intent-2", source: "text", rawText: "Plan the next slice")

        let result = try await adapter.handle(intent: intent)

        #expect(result.capabilityPacket == nil)
        #expect(result.traceId.isEmpty == false)
    }

    @Test("COGAdapter handles a framed task directly")
    func handleFramedTask() async throws {
        let adapter = makeAdapter()
        let frame = TaskFrame(
            taskRef: "task-3",
            userGoal: "Run the tests",
            sourceIntent: "tap",
            riskTier: .low
        )

        let result = try await adapter.handle(frame: frame)

        #expect(result.taskFrame.taskRef == "task-3")
        #expect(result.capabilityPlan.taskFrameRef == "task-3")
        #expect(result.contextBundleRef == "context-bundle:task-3")
    }

    @Test("Trace events are emitted during end-to-end handling")
    func traceEventsEmitted() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let adapter = COGAdapter(
            planner: DefaultCapabilityPlanner(),
            sdlAdapter: SDLAdapter(registryRef: "sdl://registry/test"),
            traceEmitter: emitter
        )

        let intent = Intent(id: "intent-4", source: "voice", rawText: "Implement feature X")
        _ = try await adapter.handle(intent: intent)

        let events = await sink.events
        #expect(events.count >= 5)
        #expect(await sink.events(ofKind: .intentReceived).count == 1)
        #expect(await sink.events(ofKind: .taskFramed).count == 1)
        #expect(await sink.events(ofKind: .planProduced).count == 1)
        #expect(await sink.events(ofKind: .routeSelected).count >= 1)
        #expect(await sink.events(ofKind: .capabilityInvoked).count == 1)
    }
}
