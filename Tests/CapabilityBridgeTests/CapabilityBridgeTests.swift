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
            contractVersion: "0.2.0",
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
            contractVersion: "0.2.0",
            traceID: traceID,
            activeDeviceID: "test-device",
            transportPath: .offline,
            tabs: [],
            surfaces: [],
            hosts: [],
            timestamp: 1_000
        )
    }

    @Test("TaskFrame can be constructed with defaults")
    func taskFrameDefaults() async throws {
        let frame = TaskFrame(taskRef: "test-1", userGoal: "Test goal", sourceIntent: "voice")
        #expect(frame.riskTier == .low)
        #expect(frame.autonomyMode == .advise)
        #expect(frame.status == .new)
    }

    @Test("ApprovalRequest starts pending")
    func approvalPending() async throws {
        let request = ApprovalRequest(
            riskTier: .medium,
            requestedAction: "edit README",
            scope: "docs/README.md"
        )
        #expect(request.approvalState == .pending)
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
            contractVersion: "0.2.0",
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
            contractVersion: "0.2.0",
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
            contractVersion: "0.2.0",
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
            contractVersion: "0.2.0",
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

@Suite("Intent -> TaskFrame -> CapabilityPlan")
struct RoutingPipelineTests {

    private let planner = DefaultCapabilityPlanner()

    @Test("Planner frames an intent into a task frame")
    func intentToFrame() async throws {
        let intent = Intent(
            id: "intent-1",
            source: "voice",
            rawText: "Run the tests in an isolated worktree",
            metadata: ["workspaceTarget": "capability-bridge"]
        )

        let frame = try await planner.frame(intent: intent)

        #expect(frame.taskRef == "intent-1")
        #expect(frame.userGoal == intent.rawText)
        #expect(frame.sourceIntent == "voice")
        #expect(frame.workspaceTarget == "capability-bridge")
        #expect(frame.status == .framed)
    }

    @Test("Planner produces a high-confidence execution plan for implementation intents")
    func implementationPlan() async throws {
        let intent = Intent(
            id: "intent-2",
            source: "text",
            rawText: "Implement the Phase 1 contracts slice in an isolated worktree"
        )

        let plan = try await planner.plan(intent: intent)

        #expect(plan.primaryRoute.capability == "capability-session-orchestrator")
        #expect(plan.primaryRoute.invocationMode == .execute)
        #expect(plan.confidence == .high)
        #expect(plan.estimatedRiskTier == .medium)
        #expect(plan.authorityRequired.contains("allow_mutation"))
        #expect(plan.authorityRequired.contains("branch_or_worktree_isolation"))
    }

    @Test("Planner includes fallback routes when confidence is not high")
    func fallbackRoutes() async throws {
        let intent = Intent(
            id: "intent-3",
            source: "text",
            rawText: "Check the schema contract"
        )

        let plan = try await planner.plan(intent: intent)

        #expect(plan.hasFallbacks)
        #expect(plan.fallbackRoutes.count > 0)
        #expect(plan.fallbackRoutes.first?.capability != plan.primaryRoute.capability)
    }

    @Test("Planner degrades to workflow-router fallback when no rule matches well")
    func noMatchEscalation() async throws {
        let intent = Intent(
            id: "intent-4",
            source: "tap",
            rawText: "Something something"
        )

        let plan = try await planner.plan(intent: intent)

        #expect(plan.primaryRoute.capability == "capability-workflow-router")
        #expect(plan.hasFallbacks)
    }

    @Test("Planner throws when no route can be determined")
    func routingFailure() async throws {
        let emptyPlanner = DefaultCapabilityPlanner(rules: [])
        let intent = Intent(id: "intent-5", source: "text", rawText: "Anything")

        await #expect(throws: RoutingError.self) {
            try await emptyPlanner.plan(intent: intent)
        }
    }

    @Test("Routing confidence ordering is correct")
    func confidenceOrdering() async throws {
        #expect(RoutingConfidence.none.isExecutableWithoutApproval == false)
        #expect(RoutingConfidence.low.isExecutableWithoutApproval == false)
        #expect(RoutingConfidence.medium.isExecutableWithoutApproval == false)
        #expect(RoutingConfidence.high.isExecutableWithoutApproval == true)
        #expect(RoutingConfidence.certain.isExecutableWithoutApproval == true)

        #expect(RoutingConfidence.none.requiresEscalation == true)
        #expect(RoutingConfidence.low.requiresEscalation == true)
        #expect(RoutingConfidence.medium.requiresEscalation == false)
    }
}

@Suite("Trace event requirements")
struct TraceEventRequirementTests {

    @Test("Valid trace event passes validation")
    func validEvent() async throws {
        let event = TraceEventBuilder(
            eventType: .taskFramed,
            traceId: "trace-1",
            subjectRef: "task-1",
            status: "ok",
            outcome: "framed",
            payloadSummary: "Task framed from voice intent",
            payloadHash: "sha256:abc123",
            attributes: [
                "taskFrame.taskRef": "task-1",
                "taskFrame.riskTier": "low",
                "taskFrame.autonomyMode": "advise"
            ]
        ).build()

        #expect(TraceEventRequirements.validate(event).isValid)
    }

    @Test("Missing required field fails validation")
    func missingField() async throws {
        let event = TraceEvent(
            eventID: "event-1",
            eventType: TraceEventKind.taskFramed.rawValue,
            traceId: "trace-1",
            subjectRef: "task-1",
            status: "ok",
            outcome: "framed",
            payloadSummary: "",
            payloadHash: "sha256:abc123"
        )

        let result = TraceEventRequirements.validate(event)
        #expect(result.isValid == false)
        #expect(result.violations.contains("empty 'payloadSummary'"))
    }

    @Test("Unknown event type fails validation")
    func unknownEventType() async throws {
        let event = TraceEventBuilder(
            eventType: .taskFramed,
            traceId: "trace-1",
            subjectRef: "task-1",
            status: "ok",
            outcome: "framed",
            payloadSummary: "summary",
            payloadHash: "sha256:abc123"
        ).build()

        let mutated = TraceEvent(
            eventID: event.eventID,
            eventType: "unknown.kind",
            traceId: event.traceId,
            subjectRef: event.subjectRef,
            status: event.status,
            outcome: event.outcome,
            payloadSummary: event.payloadSummary,
            payloadHash: event.payloadHash
        )

        let result = TraceEventRequirements.validate(mutated)
        #expect(result.isValid == false)
        #expect(result.violations.contains("unrecognized eventType 'unknown.kind'"))
    }

    @Test("All known trace event kinds have requirements")
    func allKindsHaveRequirements() async throws {
        for kind in TraceEventKind.allCases {
            let reqs = TraceEventRequirements.requirements(for: kind)
            #expect(reqs.isEmpty == false)
        }
    }
}
