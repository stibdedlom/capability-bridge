import Testing
@testable import CapabilityBridge
@testable import PaneBackends

@Suite("Capability Bridge core types")
struct CapabilityBridgeCoreTests {

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

@Suite("Pane backends")
struct PaneBackendTests {

    @Test("MockPaneBackend spawns and lists sessions")
    func mockBackendSpawns() async throws {
        let backend = MockPaneBackend(backendID: "test")
        let id = try await backend.spawnSession(id: "s1", role: "worker", command: "echo hi")
        #expect(id == "s1")

        let sessions = await backend.listSessions()
        #expect(sessions.count == 1)
        #expect(sessions.first?.status == .running)
        #expect(sessions.first?.role == "worker")
    }

    @Test("MockPaneBackend captures input and output")
    func mockBackendIO() async throws {
        let backend = MockPaneBackend(backendID: "test")
        try await backend.spawnSession(id: "s1", role: "worker", command: nil)
        try await backend.sendInput(sessionID: "s1", input: "hello")
        let output = try await backend.readOutput(sessionID: "s1")
        #expect(output.contains(">> hello"))
    }

    @Test("MockPaneBackend stops sessions")
    func mockBackendStop() async throws {
        let backend = MockPaneBackend(backendID: "test")
        try await backend.spawnSession(id: "s1", role: "worker", command: nil)
        try await backend.stopSession(sessionID: "s1")
        let sessions = await backend.listSessions()
        #expect(sessions.first?.status == .stopped)
    }

    @Test("PaneBackendRegistry resolves roles")
    func registryResolves() async throws {
        let backend = MockPaneBackend(backendID: "mock")
        let registry = PaneBackendRegistry()
        await registry.register(backend)
        await registry.mapRole("worker", toBackend: "mock")

        let resolved = try await registry.backend(forRole: "worker")
        #expect(resolved.backendID == "mock")
    }
}

@Suite("Durable task state")
struct TaskStateTests {

    @Test("InMemoryStateStore round-trips state")
    func stateStoreRoundTrip() async throws {
        let store = InMemoryStateStore()
        let frame = TaskFrame(taskRef: "t1", userGoal: "g", sourceIntent: "voice")
        let state = TaskState(taskRef: "t1", phase: .executing, frame: frame)
        try await store.save(state)

        let loaded = try await store.load(taskRef: "t1")
        #expect(loaded?.phase == .executing)
        #expect(loaded?.frame.taskRef == "t1")

        let refs = try await store.list()
        #expect(refs.contains("t1"))

        try await store.delete(taskRef: "t1")
        #expect(try await store.load(taskRef: "t1") == nil)
    }
}

@Suite("Bounded loops")
struct BoundedLoopTests {

    @Test("IterationLimit stops the loop")
    func iterationLimit() async throws {
        let loop = BoundedLoop(taskRef: "t1", conditions: [IterationLimit(3)])
        let context = LoopContext(taskRef: "t1")
        let result = await loop.run(context: context) { _ in .continued }
        #expect(result.iteration == 3)
        if case .stopped(let signal, _) = result.lastResult {
            #expect(signal == .iterationLimitReached)
        } else {
            Issue.record("Expected stopped result")
        }
    }

    @Test("SignalStop stops the loop")
    func signalStop() async throws {
        let loop = BoundedLoop(taskRef: "t1", conditions: [SignalStop()])
        var context = LoopContext(taskRef: "t1")
        context.stopSignals.append(.reviewerRequestedHalt)
        let result = await loop.run(context: context) { _ in .continued }
        #expect(result.iteration == 0)
        if case .stopped(let signal, _) = result.lastResult {
            #expect(signal == .reviewerRequestedHalt)
        } else {
            Issue.record("Expected stopped result")
        }
    }

    @Test("ErrorThreshold stops after consecutive failures")
    func errorThreshold() async throws {
        let loop = BoundedLoop(taskRef: "t1", conditions: [ErrorThreshold(2)])
        let context = LoopContext(taskRef: "t1")
        let result = await loop.run(context: context) { _ in .failed("boom") }
        #expect(result.iteration == 2)
        if case .stopped(let signal, _) = result.lastResult {
            #expect(signal == .errorThreshold)
        } else {
            Issue.record("Expected stopped result")
        }
    }
}

@Suite("Session health")
struct SessionHealthTests {

    @Test("BackendStatusHealthCheck reflects running session")
    func runningSessionHealthy() async throws {
        let backend = MockPaneBackend(backendID: "test")
        _ = try await backend.spawnSession(id: "s1", role: "worker", command: nil)
        let monitor = SessionHealthMonitor(backend: backend, checks: [BackendStatusHealthCheck()])
        let status = await monitor.aggregateStatus(for: "s1")
        #expect(status == .healthy)
    }

    @Test("Health monitor detects unresponsive session")
    func unresponsiveSessionDetected() async throws {
        let backend = MockPaneBackend(backendID: "test")
        _ = try await backend.spawnSession(id: "s1", role: "worker", command: nil)
        try await backend.simulateUnresponsive(sessionID: "s1")
        let monitor = SessionHealthMonitor(backend: backend, checks: [BackendStatusHealthCheck()])
        let status = await monitor.aggregateStatus(for: "s1")
        #expect(status == .unresponsive)
    }
}
