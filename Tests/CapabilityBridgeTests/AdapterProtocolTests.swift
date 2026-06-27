import Foundation
import Testing
@testable import CapabilityBridge
@testable import CapabilityBridgeCOG

@Suite("Adapter protocol facades")
struct AdapterProtocolTests {

    private struct StubCapabilityPlanner: CapabilityPlanner {
        func frame(intent: Intent) async throws -> TaskFrame {
            TaskFrame(
                taskRef: intent.id,
                userGoal: intent.rawText,
                sourceIntent: intent.source,
                riskTier: .low,
                autonomyMode: .advise,
                status: .framed
            )
        }

        func plan(frame: TaskFrame) async throws -> CapabilityPlan {
            CapabilityPlan(
                taskFrameRef: frame.taskRef,
                primaryRoute: Route(
                    capability: "capability-workflow-router",
                    invocationMode: .dryRun,
                    reason: "Stub plan",
                    confidence: .high
                ),
                estimatedRiskTier: .low
            )
        }
    }

    private struct StubSDLAdapter: SDLAdapterProtocol {
        let packet = CapabilityPacket(
            mode: "stub-mode",
            selectedCapability: "stub-capability",
            invocationMode: .dryRun,
            inputs: ["stub": "value"],
            contextBundleRef: "stub-bundle",
            authorityScope: ["stub-scope"],
            allowMutation: false,
            expectedOutputs: ["stub-output"]
        )
        let bundleRef = "stub-bundle-ref"
        let bundle = ContextBundle(workspaceSnapshot: "stub-snapshot")

        func adapt(
            plan: CapabilityPlan,
            contextBundle: ContextBundle,
            contextBundleRef: String,
            approvedScope: [String]?
        ) throws -> CapabilityPacket {
            packet
        }

        func assembleContextBundle(
            for frame: TaskFrame,
            plan: CapabilityPlan?
        ) -> (ref: String, bundle: ContextBundle) {
            (bundleRef, bundle)
        }
    }

    @Test("COGAdapter uses a stub SDLAdapterProtocol")
    func cogAdapterUsesStubSDLAdapter() async throws {
        let planner = StubCapabilityPlanner()
        let sdlStub = StubSDLAdapter()
        let sink = InMemoryTraceEventSink()
        let emitter = TraceEventEmitter(sink: sink)
        let adapter = COGAdapter(
            planner: planner,
            sdlAdapter: sdlStub,
            traceEmitter: emitter,
            includePacketInResult: true
        )

        let intent = Intent(id: "stub-intent", source: "test", rawText: "stub request")
        let result = try await adapter.handle(intent: intent)

        #expect(result.taskFrame.taskRef == intent.id)
        #expect(result.capabilityPlan.taskFrameRef == intent.id)
        #expect(result.capabilityPacket == sdlStub.packet)
        #expect(result.contextBundleRef == sdlStub.bundleRef)
    }
}
