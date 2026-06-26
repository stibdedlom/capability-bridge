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
