import Testing
@testable import CapabilityBridge
@testable import CapabilityBridgeCOG
@testable import CapabilityBridgeSDL
@testable import ApprovalSurfaces

@Suite("Approval surfaces")
struct ApprovalSurfaceTests {

    private func makeAdapter(surface: (any ApprovalSurface)?) -> COGAdapter {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        return COGAdapter(
            planner: DefaultCapabilityPlanner(),
            sdlAdapter: SDLAdapter(registryRef: "sdl://registry/test"),
            traceEmitter: emitter,
            approvalSurface: surface
        )
    }

    @Test("Approved surface allows execution to proceed")
    func approvedExecution() async throws {
        let surface = StubApprovalSurface(
            response: BridgeApprovalResponse(
                requestRef: "approval-1",
                approvalState: "approved"
            )
        )
        let adapter = makeAdapter(surface: surface)
        let intent = Intent(id: "intent-1", source: "voice", rawText: "Delete the old branch")

        let result = try await adapter.handle(intent: intent)

        #expect(result.status == "ok")
        #expect(result.capabilityPlan.estimatedRiskTier == "high")
    }

    @Test("Denied surface throws approval denied error")
    func deniedExecution() async throws {
        let surface = StubApprovalSurface(
            response: BridgeApprovalResponse(
                requestRef: "approval-2",
                approvalState: "denied"
            )
        )
        let adapter = makeAdapter(surface: surface)
        let intent = Intent(id: "intent-2", source: "voice", rawText: "Delete the old branch")

        await #expect(throws: COGAdapterError.self) {
            try await adapter.handle(intent: intent)
        }
    }

    @Test("Missing surface throws when approval is required")
    func missingSurface() async throws {
        let adapter = makeAdapter(surface: nil)
        let intent = Intent(id: "intent-3", source: "voice", rawText: "Delete the old branch")

        await #expect(throws: COGAdapterError.self) {
            try await adapter.handle(intent: intent)
        }
    }

    @Test("Low-risk intent bypasses approval")
    func lowRiskNoApproval() async throws {
        let adapter = makeAdapter(surface: nil)
        let intent = Intent(id: "intent-4", source: "text", rawText: "Plan the next slice")

        let result = try await adapter.handle(intent: intent)

        #expect(result.status == "ok")
    }

    @Test("Approval trace events are emitted")
    func approvalTraceEvents() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let surface = StubApprovalSurface(
            response: BridgeApprovalResponse(requestRef: "approval-trace-1", approvalState: "approved", approvedScope: ["allow_mutation"])
        )
        let adapter = COGAdapter(
            planner: DefaultCapabilityPlanner(),
            sdlAdapter: SDLAdapter(registryRef: "sdl://registry/test"),
            traceEmitter: emitter,
            approvalSurface: surface
        )

        let intent = Intent(id: "intent-5", source: "voice", rawText: "Delete the old branch")
        _ = try await adapter.handle(intent: intent)

        #expect(await sink.events(ofKind: .approvalRequested).count == 1)
        #expect(await sink.events(ofKind: .approvalResolved).count == 1)

        let resolved = await sink.events(ofKind: .approvalResolved).first!
        #expect(resolved.approvalRefs.contains("approval-trace-1"))
        #expect(resolved.attributes["approvalRequest.approvalState"] == "approved")
    }

    @Test("handle(frame:) applies approval gating")
    func framedTaskApprovalGating() async throws {
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let surface = StubApprovalSurface(
            response: BridgeApprovalResponse(requestRef: "approval-frame-1", approvalState: "approved", approvedScope: ["allow_mutation"])
        )
        let adapter = COGAdapter(
            planner: DefaultCapabilityPlanner(),
            sdlAdapter: SDLAdapter(registryRef: "sdl://registry/test"),
            traceEmitter: emitter,
            approvalSurface: surface
        )

        let frame = TaskFrame(
            taskRef: "task-frame-1",
            userGoal: "Delete the old branch",
            sourceIntent: "tap",
            riskTier: "high"
        )

        let result = try await adapter.handle(frame: frame)
        #expect(result.status == "ok")
        #expect(await sink.events(ofKind: .approvalRequested).count == 1)
    }

    @Test("Approved scope narrows packet authority")
    func approvedScopeNarrowsAuthority() async throws {
        let surface = StubApprovalSurface(
            response: BridgeApprovalResponse(requestRef: "approval-narrow-1", approvalState: "approved", approvedScope: ["branch_or_worktree_isolation"])
        )
        let adapter = makeAdapter(surface: surface)
        let intent = Intent(id: "intent-6", source: "voice", rawText: "Delete the old branch")

        let result = try await adapter.handle(intent: intent)

        #expect(result.capabilityPacket?.allowMutation == false)
        #expect(result.capabilityPacket?.authorityScope.contains("allow_mutation") == false)
    }

    @Test("ApprovalResponse isApproved reflects state")
    func responseState() async throws {
        let approved = BridgeApprovalResponse(requestRef: "a", approvalState: "approved")
        let denied = BridgeApprovalResponse(requestRef: "b", approvalState: "denied")

        #expect(approved.isApproved == true)
        #expect(denied.isApproved == false)
    }
}
