import Testing
@testable import CapabilityBridge
@testable import CapabilityBridgeSDL

@Suite("SDL Adapter")
struct SDLAdapterTests {

    private let adapter = SDLAdapter(
        registryRef: "sdl://registry/test",
        lifecycleRecordRef: "lifecycle://79e8f711-16b9-4d4c-b865-75a67c374521"
    )

    private func makePlan(
        invocationMode: String = "execute",
        authority: [String] = ["allow_mutation"],
        fallbacks: [Route] = []
    ) -> CapabilityPlan {
        CapabilityPlan(
            taskFrameRef: "task-1",
            primaryRoute: Route(
                capability: "capability-session-orchestrator",
                invocationMode: invocationMode,
                reason: "Implementation request",
                confidence: .high
            ),
            fallbackRoutes: fallbacks,
            authorityRequired: authority,
            tracePolicy: "emit-all",
            estimatedRiskTier: "medium"
        )
    }

    @Test("Adapter produces a CapabilityPacket from a plan")
    func adaptPlanToPacket() async throws {
        let plan = makePlan()
        let frame = TaskFrame(taskRef: "task-1", userGoal: "Implement", sourceIntent: "text")
        let (_, bundle) = adapter.assembleContextBundle(for: frame, plan: plan)

        let packet = try adapter.adapt(plan: plan, contextBundle: bundle, contextBundleRef: "bundle-1")

        #expect(packet.selectedCapability == "capability-session-orchestrator")
        #expect(packet.invocationMode == "execute")
        #expect(packet.contextBundleRef == "bundle-1")
        #expect(packet.allowMutation == true)
        #expect(packet.authorityScope.contains("allow_mutation"))
        #expect(packet.inputs["lifecycleRecordRef"] == "lifecycle://79e8f711-16b9-4d4c-b865-75a67c374521")
        #expect(packet.inputs["registryRef"] == "sdl://registry/test")
    }

    @Test("Adapter defaults to dry-run when route has no invocation mode")
    func defaultInvocationMode() async throws {
        let plan = CapabilityPlan(
            taskFrameRef: "task-2",
            primaryRoute: Route(
                capability: "capability-workflow-router",
                invocationMode: "",
                reason: "Empty mode",
                confidence: .medium
            ),
            authorityRequired: [],
            estimatedRiskTier: "low"
        )

        let packet = try adapter.adapt(
            plan: plan,
            contextBundle: ContextBundle(),
            contextBundleRef: "bundle-2"
        )

        #expect(packet.invocationMode == "dry-run")
        #expect(packet.allowMutation == false)
    }

    @Test("Adapter withholds mutation when approval gate is required")
    func mutationBlockedByApprovalGate() async throws {
        let plan = makePlan(authority: ["allow_mutation", "approval-gate"])
        let packet = try adapter.adapt(
            plan: plan,
            contextBundle: ContextBundle(),
            contextBundleRef: "bundle-3"
        )

        #expect(packet.allowMutation == false)
    }

    @Test("Adapter includes fallback capabilities in packet inputs")
    func fallbackInputs() async throws {
        let plan = makePlan(fallbacks: [
            Route(capability: "capability-workflow-router", reason: "Fallback", confidence: .medium)
        ])
        let packet = try adapter.adapt(
            plan: plan,
            contextBundle: ContextBundle(),
            contextBundleRef: "bundle-4"
        )

        #expect(packet.inputs["fallbackCapabilities"] == "capability-workflow-router")
    }

    @Test("Adapter throws when primary route capability is empty")
    func emptyPrimaryRoute() async throws {
        let plan = CapabilityPlan(
            taskFrameRef: "task-3",
            primaryRoute: Route(capability: "", reason: "Empty", confidence: .none),
            estimatedRiskTier: "low"
        )

        #expect(throws: SDLAdapterError.self) {
            try adapter.adapt(
                plan: plan,
                contextBundle: ContextBundle(),
                contextBundleRef: "bundle-5"
            )
        }
    }

    @Test("Context bundle assembly redacts high-risk frames")
    func highRiskContextBundle() async throws {
        let frame = TaskFrame(
            taskRef: "task-4",
            userGoal: "Delete production data",
            sourceIntent: "voice",
            riskTier: "high"
        )

        let (ref, bundle) = adapter.assembleContextBundle(for: frame, plan: nil)

        #expect(ref == "context-bundle:task-4")
        #expect(bundle.rawContentPolicy == "redact-sensitive")
        #expect(bundle.omissions.contains { $0.contains("riskTier=high") })
    }
}
