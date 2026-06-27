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

    @Test("ApprovalResponse isApproved reflects state")
    func responseState() async throws {
        let approved = BridgeApprovalResponse(requestRef: "a", approvalState: "approved")
        let denied = BridgeApprovalResponse(requestRef: "b", approvalState: "denied")

        #expect(approved.isApproved == true)
        #expect(denied.isApproved == false)
    }
}
