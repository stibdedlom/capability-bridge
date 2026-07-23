import Foundation
import Testing
@testable import CapabilityBridge

@Suite("Codable round-trips")
struct CodableRoundTripTests {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return try decoder.decode(T.self, from: data)
    }

    @Test("Intent round-trips")
    func intentRoundTrip() throws {
        let value = Intent(
            id: "intent-1",
            source: "voice",
            rawText: "Run the tests",
            locale: "en-US",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceRef: "device-1",
            sessionRef: "session-1",
            metadata: ["workspaceTarget": "capability-bridge"]
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("TaskFrame round-trips")
    func taskFrameRoundTrip() throws {
        let value = TaskFrame(
            taskRef: "task-1",
            userGoal: "Implement feature X",
            sourceIntent: "text",
            workspaceTarget: "capability-bridge",
            repoContext: "v-i-s-h-a-l/capability-bridge",
            riskTier: .high,
            autonomyMode: .execute,
            requestedOutcome: "A working slice",
            constraints: ["no secrets"],
            status: .planned,
            openQuestions: ["Which API?"]
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("CapabilityPlan and Route round-trip")
    func capabilityPlanRoundTrip() throws {
        let value = CapabilityPlan(
            taskFrameRef: "task-1",
            primaryRoute: Route(
                capability: "capability-session-orchestrator",
                invocationMode: .execute,
                reason: "Implementation request",
                confidence: .high
            ),
            fallbackRoutes: [
                Route(
                    capability: "capability-workflow-router",
                    invocationMode: .dryRun,
                    reason: "Fallback",
                    confidence: .medium
                )
            ],
            authorityRequired: ["allow_mutation"],
            tracePolicy: "emit-all",
            estimatedRiskTier: .medium
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("CapabilityPacket round-trips")
    func capabilityPacketRoundTrip() throws {
        let value = CapabilityPacket(
            mode: "execute",
            selectedCapability: "capability-session-orchestrator",
            invocationMode: .execute,
            inputs: ["taskFrameRef": "task-1"],
            contextBundleRef: "bundle-1",
            authorityScope: ["allow_mutation"],
            allowMutation: true,
            expectedOutputs: ["artifactSummary"]
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("ContextBundle round-trips")
    func contextBundleRoundTrip() throws {
        let value = ContextBundle(
            workspaceSnapshot: "snapshot",
            noteRefs: ["note-1"],
            memorySnippets: ["memory-1"],
            artifactRefs: ["artifact-1"],
            auraRefs: ["aur-1"],
            omissions: ["redacted"],
            freshness: Date(timeIntervalSince1970: 1_700_000_000),
            tokenBudget: 8192,
            rawContentPolicy: "redact-sensitive"
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("ApprovalRequest round-trips")
    func approvalRequestRoundTrip() throws {
        let value = ApprovalRequest(
            riskTier: .critical,
            requestedAction: "Delete production data",
            evidenceRefs: ["evidence-1"],
            scope: "production/db",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            prohibitedActions: ["drop table"],
            confirmationRitual: "hold-to-confirm",
            approvalState: .pending
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("BridgeApprovalResponse round-trips")
    func bridgeApprovalResponseRoundTrip() throws {
        let value = BridgeApprovalResponse(
            requestRef: "approval-1",
            approvalState: .approved,
            approvedScope: ["allow_mutation"],
            deniedActions: ["access secrets"],
            respondedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("TraceEvent round-trips")
    func traceEventRoundTrip() throws {
        let value = TraceEvent(
            eventID: "event-1",
            eventType: TraceEventKind.taskFramed.rawValue,
            traceId: "trace-1",
            parentEventID: "parent-1",
            subjectRef: "task-1",
            status: "ok",
            outcome: "task framed",
            payloadSummary: "summary",
            payloadHash: "sha256:abc",
            artifactRefs: ["artifact-1"],
            approvalRefs: ["approval-1"],
            attributes: ["taskFrame.riskTier": "low"]
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("ArtifactSummary round-trips")
    func artifactSummaryRoundTrip() throws {
        let value = ArtifactSummary(
            artifactRef: "artifact-1",
            artifactType: "file",
            pathOrURI: "file:///tmp/result.md",
            fingerprint: "sha256:def",
            producerCapability: "capability-session-orchestrator",
            title: "Result",
            summary: "A result",
            conformanceSummary: "conforms",
            redactionState: "none"
        )
        #expect(try roundTrip(value) == value)
    }

    @Test("BridgeResult round-trips")
    func bridgeResultRoundTrip() throws {
        let frame = TaskFrame(
            taskRef: "task-1",
            userGoal: "Implement",
            sourceIntent: "text",
            riskTier: .medium,
            autonomyMode: .plan,
            status: .approved
        )
        let plan = CapabilityPlan(
            taskFrameRef: "task-1",
            primaryRoute: Route(
                capability: "capability-session-orchestrator",
                invocationMode: .execute,
                reason: "Implementation",
                confidence: .high
            ),
            estimatedRiskTier: .medium
        )
        let packet = CapabilityPacket(
            mode: "execute",
            selectedCapability: "capability-session-orchestrator",
            invocationMode: .execute,
            contextBundleRef: "bundle-1",
            authorityScope: ["allow_mutation"],
            allowMutation: true,
            expectedOutputs: ["artifactSummary"]
        )
        let value = BridgeResult(
            traceId: "trace-1",
            taskFrame: frame,
            capabilityPlan: plan,
            capabilityPacket: packet,
            contextBundleRef: "bundle-1",
            status: "ok",
            summary: "Done"
        )
        #expect(try roundTrip(value) == value)
    }
}
