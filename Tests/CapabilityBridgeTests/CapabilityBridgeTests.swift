import Testing
import WorkspaceTypes
@testable import CapabilityBridge
@testable import CapabilityBridgeCOG
@testable import CapabilityBridgeSDL
@testable import PaneBackends

@Suite("Capability Bridge COG-SDL refactor")
struct CapabilityBridgeTests {

    // MARK: - Fixtures

    private func makeIntent(
        action: Action,
        userGoal: String = "test goal",
        traceID: String = "trace-1"
    ) -> CogIntent {
        CogIntent(
            contractVersion: "0.1.0",
            traceID: traceID,
            sourceIntent: Intent(
                action: action,
                source: .voice,
                confidence: 0.95
            ),
            userGoal: userGoal,
            targetQuery: nil,
            locale: "en-US",
            confidence: 0.95,
            transcription: userGoal,
            rawAudioRef: nil,
            timestamp: 1_000
        )
    }

    private func makeContext(traceID: String = "trace-1") -> CogContext {
        CogContext(
            contractVersion: "0.1.0",
            traceID: traceID,
            activeDeviceID: "test-device",
            transportPath: .offline,
            tabs: [],
            surfaces: [],
            hosts: [],
            timestamp: 1_000
        )
    }

    // MARK: - CapabilityBridge core state

    @Test("TaskState uses CogTaskFrame")
    func taskStateUsesCogTaskFrame() async throws {
        let intent = makeIntent(action: .readOutput)
        let context = makeContext()
        let adapter = CogIntentAdapter()
        let frame = await adapter.adapt(intent: intent, context: context)

        let state = TaskState(frame: frame, createdAt: frame.createdAt)
        #expect(state.frame.traceID == intent.traceID)
        #expect(state.frame.intent == intent)
        #expect(state.phase == .pending)
    }

    // MARK: - CogIntentAdapter

    @Test("CogIntentAdapter classifies readOutput as safe")
    func cogAdapterSafeRisk() async throws {
        let intent = makeIntent(action: .readOutput)
        let context = makeContext()
        let adapter = CogIntentAdapter()
        let frame = await adapter.adapt(intent: intent, context: context)
        #expect(frame.riskTier == .safe)
        #expect(frame.scope == .observe)
        #expect(frame.status == .new)
    }

    @Test("CogIntentAdapter classifies addRule as high risk")
    func cogAdapterHighRisk() async throws {
        let intent = makeIntent(action: .addRule, userGoal: "add a proactive rule")
        let context = makeContext()
        let adapter = CogIntentAdapter()
        let frame = await adapter.adapt(intent: intent, context: context)
        #expect(frame.riskTier == .high)
    }

    @Test("CogIntentAdapter adapt(response:) returns nil in V0")
    func cogAdapterApprovalResponseStub() async throws {
        let response = CogApprovalResponse(
            contractVersion: "0.1.0",
            traceID: "trace-1",
            approvalRef: "approval-1",
            decision: .approved,
            responderIdentity: "user-test",
            timestamp: 2_000
        )
        let adapter = CogIntentAdapter()
        let packet = await adapter.adapt(response: response)
        #expect(packet == nil)
    }

    // MARK: - CogContextBundleBuilder

    @Test("ContextBundle builder captures bounded context fields")
    func contextBundleBuilder() async throws {
        let context = CogContext(
            contractVersion: "0.1.0",
            traceID: "trace-1",
            activeDeviceID: "device-1",
            transportPath: .bonjour,
            tabs: [
                CogTabSnapshot(
                    id: "tab-1",
                    type: .terminal,
                    title: "Test Tab",
                    status: .running,
                    surfaceID: "surface-1",
                    hostID: "host-1"
                )
            ],
            surfaces: [
                CogSurfaceSnapshot(
                    id: "surface-1",
                    type: .terminalMultiplexer,
                    hostID: "host-1",
                    tabs: ["tab-1"],
                    activeTabID: "tab-1"
                )
            ],
            hosts: [
                CogHostSnapshot(
                    id: "host-1",
                    type: .tmux,
                    name: "Test Host",
                    capabilities: [.readOutput],
                    status: .connected,
                    lastHeartbeat: 1_000
                )
            ],
            activeTabID: "tab-1",
            activeSurfaceID: "surface-1",
            noteRefs: ["note-1"],
            tokenBudget: 2048,
            rawContentPolicy: "redact-sensitive",
            timestamp: 5_000
        )

        let builder = CogContextBundleBuilder()
        let bundle = builder.build(from: context)

        #expect(bundle.noteRefs == ["note-1"])
        #expect(bundle.tokenBudget == 2048)
        #expect(bundle.rawContentPolicy == "redact-sensitive")
        #expect(bundle.omissions == ["raw_output"])
        #expect(bundle.workspaceSnapshot.contains("tab-1"))
        #expect(bundle.workspaceSnapshot.contains("surface-1"))
    }

    // MARK: - SDL Adapter

    @Test("SdlBridgeAdapter returns a one-step observe/advise plan")
    func sdlAdapterPlan() async throws {
        let intent = makeIntent(action: .readOutput, userGoal: "read the latest output")
        let context = makeContext()
        let cogAdapter = CogIntentAdapter()
        let frame = await cogAdapter.adapt(intent: intent, context: context)

        let sdlAdapter = SdlBridgeAdapter()
        let result = await sdlAdapter.submit(frame)
        let plan = try result.get()

        #expect(plan.steps.count == 1)
        #expect(plan.steps.first?.capability == "observe-advise")
        #expect(plan.estimatedRisk == .safe)
        #expect(plan.requiredApprovals.isEmpty)
    }

    @Test("SdlBridgeAdapter requires approval for high-risk frames")
    func sdlAdapterApprovalRequired() async throws {
        let intent = makeIntent(action: .addRule, userGoal: "add a proactive rule")
        let context = makeContext()
        let cogAdapter = CogIntentAdapter()
        let frame = await cogAdapter.adapt(intent: intent, context: context)

        let sdlAdapter = SdlBridgeAdapter()
        let result = await sdlAdapter.submit(frame)
        let plan = try result.get()

        #expect(plan.estimatedRisk == .high)
        #expect(plan.requiredApprovals.count == 1)
        #expect(plan.steps.first?.requiresApproval == true)
    }

    @Test("SdlBridgeAdapter respond returns success(nil)")
    func sdlAdapterRespond() async throws {
        let response = CogApprovalResponse(
            contractVersion: "0.1.0",
            traceID: "trace-1",
            approvalRef: "approval-1",
            decision: .approved,
            responderIdentity: "user-test",
            timestamp: 2_000
        )
        let sdlAdapter = SdlBridgeAdapter()
        let result = await sdlAdapter.respond(to: "approval-1", with: response)
        #expect(try result.get() == nil)
    }

    @Test("TraceEventEmitter records without error")
    func traceEmitterNoOp() async throws {
        let emitter = TraceEventEmitter()
        let event = CogTraceEvent(
            contractVersion: "0.1.0",
            traceID: "trace-1",
            eventID: "event-1",
            eventType: "test",
            subjectRef: "subject-1",
            status: "ok",
            outcome: "observed",
            payloadSummary: "summary",
            payloadHash: "hash",
            timestamp: 1_000
        )
        await emitter.emit(event)
        #expect(Bool(true))
    }

    // MARK: - Pane Backends

    @Test("MockPaneBackend readOutput returns a Chunk")
    func mockPaneBackendChunk() async throws {
        let backend = MockPaneBackend()
        let sessionID = try await backend.spawnSession(id: "session-1", role: "test", command: nil)
        try await backend.sendInput(sessionID: sessionID, input: "hello")
        let chunk = try await backend.readOutput(sessionID: sessionID)

        #expect(chunk.tabID == sessionID)
        #expect(chunk.text == "hello\n")
        #expect(chunk.hasMore == false)
    }
}
