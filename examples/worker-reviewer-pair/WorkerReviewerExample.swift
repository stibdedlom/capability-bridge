import CapabilityBridge
import PaneBackends
import Foundation

/// Demonstrates a worker + reviewer visible session pair.
///
/// This example is safe to run: it uses `MockPaneBackend` and `InMemoryStateStore`,
/// so it never touches client repositories, real terminals, or SDL records.
@main
struct WorkerReviewerExample {
    static func main() async throws {
        // 1. User intent becomes a TaskFrame.
        let frame = TaskFrame(
            taskRef: "example-worker-reviewer-001",
            userGoal: "Refactor the docs README for clarity",
            sourceIntent: "voice",
            workspaceTarget: "docs",
            riskTier: "medium",
            autonomyMode: "advise",
            requestedOutcome: "Updated README with clearer structure"
        )
        print("[bridge] Created task frame: \(frame.taskRef)")

        // 2. Durable state store (in-memory for the demo).
        let store = InMemoryStateStore()
        var state = TaskState(taskRef: frame.taskRef, phase: .new, frame: frame)
        try await store.save(state)

        // 3. Create a pane backend and register worker + reviewer roles.
        let backend = MockPaneBackend(backendID: "mock")
        let registry = PaneBackendRegistry()
        await registry.register(backend)
        await registry.mapRole("worker", toBackend: "mock")
        await registry.mapRole("reviewer", toBackend: "mock")

        // 4. Spawn visible sessions.
        let workerID = try await backend.spawnSession(
            id: "worker-\(frame.taskRef)",
            role: "worker",
            command: "swift refactor-docs.swift"
        )
        let reviewerID = try await backend.spawnSession(
            id: "reviewer-\(frame.taskRef)",
            role: "reviewer",
            command: "swift review-docs.swift"
        )
        print("[bridge] Spawned worker \(workerID) and reviewer \(reviewerID)")

        state.sessions[workerID] = SessionState(
            sessionID: workerID,
            role: "worker",
            backendID: backend.backendID,
            command: "swift refactor-docs.swift",
            status: .running
        )
        state.sessions[reviewerID] = SessionState(
            sessionID: reviewerID,
            role: "reviewer",
            backendID: backend.backendID,
            command: "swift review-docs.swift",
            status: .running
        )
        state.phase = .executing
        try await store.save(state)

        // 5. Health monitor for both sessions.
        let healthMonitor = SessionHealthMonitor(
            backend: backend,
            checks: [BackendStatusHealthCheck(), OutputStalenessCheck(timeout: 5)]
        )

        // 6. Worker runs a bounded loop: plan → execute → verify → checkpoint.
        let loop = BoundedLoop(
            taskRef: frame.taskRef,
            conditions: [
                IterationLimit(4),
                TimeBudget(30),
                SignalStop()
            ]
        )
        var loopContext = LoopContext(
            taskRef: frame.taskRef,
            timeBudget: 30,
            maxIterations: 4
        )

        loopContext = await loop.run(context: loopContext) { ctx in
            print("[worker] Iteration \(ctx.iteration)")

            // Simulate worker activity.
            try? await backend.simulateOutput(
                sessionID: workerID,
                output: "Iteration \(ctx.iteration): planned, executed, verified"
            )

            // Health check.
            let health = await healthMonitor.aggregateStatus(for: workerID)
            print("[health] worker status: \(health.rawValue)")
            if health == .unresponsive {
                return .stopped(signal: .healthCheckFailed, summary: "Worker unresponsive")
            }

            // Every second iteration, reviewer checkpoints and may stop.
            if ctx.iteration.isMultiple(of: 2) {
                let checkpoint = TaskCheckpoint(
                    id: "checkpoint-\(ctx.iteration)",
                    phase: .checkpoint,
                    summary: "Reviewer checkpoint at iteration \(ctx.iteration)",
                    traceRefs: []
                )
                print("[reviewer] Checkpoint: \(checkpoint.summary)")

                // V0: reviewer always continues after checkpoint.
                // In a full flow, the reviewer could raise a stop signal here.
                if ctx.iteration == 4 {
                    return .stopped(signal: .reviewerRequestedHalt, summary: "Reviewer accepted final result")
                }
                return .checkpoint(summary: checkpoint.summary)
            }

            return .continued
        }

        // 7. Stop sessions and finalize state.
        try await backend.stopSession(sessionID: workerID)
        try await backend.stopSession(sessionID: reviewerID)

        state.phase = .completed
        state.loopContext = loopContext
        try await store.save(state)

        // 8. Print final state.
        print("[bridge] Final phase: \(state.phase.rawValue)")
        print("[bridge] Checkpoints: \(loopContext.iteration / 2)")
        print("[bridge] Sessions:")
        for summary in await backend.listSessions() {
            print("  - \(summary.id): \(summary.status.rawValue) (\(summary.role))")
        }
        print("[bridge] Loop ended at iteration \(loopContext.iteration) with result \(String(describing: loopContext.lastResult))")
    }
}
