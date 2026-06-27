import Testing
@testable import CapabilityBridge

@Suite("Capability Bridge core types")
struct CapabilityBridgeTests {

    @Test("TaskFrame can be constructed with defaults")
    func taskFrameDefaults() async throws {
        let frame = TaskFrame(taskRef: "test-1", userGoal: "Test goal", sourceIntent: "voice")
        #expect(frame.riskTier == "low")
        #expect(frame.autonomyMode == "advise")
        #expect(frame.status == "new")
    }

    @Test("CapabilityPacket defaults to no mutation")
    func packetNoMutation() async throws {
        let packet = CapabilityPacket(
            mode: "dry-run",
            selectedCapability: "test-capability",
            contextBundleRef: "bundle-1"
        )
        #expect(packet.allowMutation == false)
    }

    @Test("ApprovalRequest starts pending")
    func approvalPending() async throws {
        let request = ApprovalRequest(
            riskTier: "medium",
            requestedAction: "edit README",
            scope: "docs/README.md"
        )
        #expect(request.approvalState == "pending")
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
        #expect(frame.status == "framed")
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
        #expect(plan.primaryRoute.invocationMode == "execute")
        #expect(plan.confidence == .high)
        #expect(plan.estimatedRiskTier == "medium")
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
