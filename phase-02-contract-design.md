---
type: design
status: draft
created: 2026-06-27
task_ref: cog-bridge-contract-alignment
lifecycle_records:
  - workspace-core: 2da4239f-50fa-474f-962e-9b7d6cc3680f
  - workspace-types: b148d615-603f-4529-9494-7d292ebf6e1e
  - capability-bridge: 0c62d626-4500-4df3-9d44-1ef90e423873
contract_version: "0.2.0"
---

# Phase 2 — Contract Design

> Ratified, versioned protocol boundary between COG and SDL.

## Executive Summary

The COG-SDL contract is ratified as a new module inside `workspace-types` (`Sources/WorkspaceTypes/cog_bridge_contract/`). Every cross-boundary message carries `contractVersion: "0.2.0"`, uses typed enums where possible, and relies on `workspace-types` as the single source of truth. `capability-bridge` will consume this module and translate its existing SDL-shaped types to the shared contract; `workspace-core` will produce `CogIntent`/`CogContext`/`CogTaskFrame` without importing SDL internals.

## 1. Design Decisions

### 1.1 Canonical location: `workspace-types`

Per `BOUNDARY.md` and `REGISTRY.yml`, cross-repo contracts live in `workspace-types`. The new module is `cog_bridge_contract/` and is consumed by both `workspace-core` and `capability-bridge`.

### 1.2 Contract version: `"0.2.0"`

- `0.1.0` is already claimed by the existing `HostAdapter.contract_version` default.
- `0.2.0` marks the ratification of the COG-SDL bridge boundary.
- All new messages carry `contractVersion: String`. Consumers reject mismatched major versions.

### 1.3 In-process Swift types with defined serialization path

V0 transport is in-process: `workspace-core` and `capability-bridge` both link `workspace-types` and pass value types directly. The serialization path is JSON: struct and raw-value enum types are `Codable` (derived), while `Metadata`-carrying types and associated-value enums such as `CogTargetQuery` require consumer-side encoding adapters in `capability-bridge` and tests/fixtures. Future transport options (XPC, Network.framework `BridgeMessage`, local IPC) are documented but not implemented in V0.

### 1.4 No SDL leakage into `workspace-core`

`workspace-core` depends only on `workspace-types`. It never imports `CapabilityBridge` or any SDL module.

### 1.5 No COG UI leakage into `capability-bridge`

`capability-bridge` depends only on `workspace-types` and `Foundation`. It never imports `WorkspaceCore`, `SwiftUI`, or host adapters.

## 2. Message Catalog

All types are in `workspace-types-worktree-cog-bridge-1/Sources/WorkspaceTypes/cog_bridge_contract/`.

### 2.1 COG → SDL

| Type | File | Purpose |
|---|---|---|
| `CogIntent` | `cog_intent.swift` | User intent with locale, confidence, transcription, raw audio ref, and source `Intent`. |
| `CogContext` | `cog_context.swift` | Bounded workspace snapshot: tabs, surfaces, hosts, read state, active device, transport path, note/rule refs, token budget. |
| `CogTaskFrame` | `cog_task_frame.swift` | Canonical task envelope: intent + context + scope + risk tier + autonomy mode + constraints + status + trace ID. |
| `CogTraceEvent` | `events.swift` | Append-only correlation event emitted from COG to SDL lifecycle records. |
| `CogPaneBackendEvent` | `events.swift` | Pane lifecycle events (opened, focused, closed, status changed). |
| `CogApprovalResponse` | `approval.swift` | User's approve/deny/defer response to an SDL approval request. |
| `CogTargetQuery` / `CogTargetResolution` | `cog_target_resolution.swift` | SDL-facing target resolution using only IDs and titles, not full `Tab` objects. |

### 2.2 SDL → COG

| Type | File | Purpose |
|---|---|---|
| `SdlCapabilityPacket` | `sdl_packets.swift` | Task frame routed to an SDL capability with invocation mode, inputs, authority scope, and expected outputs. |
| `SdlCapabilityPlan` | `sdl_packets.swift` | Planned steps, estimated risk, required approvals, target refs, and summary. |
| `SdlArtifactSummary` | `sdl_packets.swift` | Compact result artifact for user display. |
| `SdlApprovalRequest` | `approval.swift` | Bidirectional approval envelope with risk tier, evidence refs, ritual, and state. |
| `CogBridgeError` | `error.swift` | Shared error envelope with code, category, retry policy, and user message. |

### 2.3 Shared enums

| Enum | File | Values |
|---|---|---|
| `CogTransportPath` | `cog_context.swift` | `bonjour`, `iCloud`, `offline` |
| `CogTaskScope` | `cog_task_frame.swift` | `observe`, `advise`, `execute` |
| `CogTaskStatus` | `cog_task_frame.swift` | `new`, `routing`, `awaitingApproval`, `executing`, `completed`, `stopped`, `failed` |
| `SdlInvocationMode` | `sdl_packets.swift` | `dryRun`, `execute`, `approvalRequired` |
| `SdlApprovalState` | `approval.swift` | `pending`, `presented`, `approved`, `denied`, `deferred`, `expired` |
| `SdlConfirmationRitual` | `approval.swift` | `tapApprove`, `explicitConfirm`, `biometric`, `watchHaptic` |
| `CogApprovalDecision` | `approval.swift` | `approved`, `denied`, `deferred` |
| `CogPaneBackendEventType` | `events.swift` | `opened`, `focused`, `closed`, `statusChanged` |
| `CogBridgeErrorCategory` | `error.swift` | `validation`, `host`, `capability`, `approval`, `transport`, `timeout`, `unknown` |
| `CogBridgeRetryPolicy` | `error.swift` | `none`, `once`, `backoff`, `afterApproval` |

Existing workspace-types enums (`RiskTier`, `Status`, `TabType`, `SurfaceType`, `HostType`, `HostCapability`, `HostStatus`) are reused directly.

## 3. Type Details

### 3.1 `CogIntent`

```swift
struct CogIntent {
    contractVersion: String
    traceID: String
    sourceIntent: Intent
    userGoal: String
    targetQuery: String?
    locale: String
    confidence: Double
    transcription: String
    rawAudioRef: String?
    timestamp: Int
}
```

Rationale: `sourceIntent` preserves the original voice/core `Intent` so SDL can fall back to COG-native semantics. `locale` and `transcription` support multilingual intent handling.

### 3.2 `CogContext`

```swift
struct CogContext {
    contractVersion: String
    traceID: String
    activeDeviceID: String
    transportPath: CogTransportPath
    tabs: [CogTabSnapshot]
    surfaces: [CogSurfaceSnapshot]
    hosts: [CogHostSnapshot]
    readStates: [CogReadState]
    activeTabID: String?
    activeSurfaceID: String?
    noteRefs: [String]
    ruleRefs: [String]
    tokenBudget: Int
    rawContentPolicy: String
    timestamp: Int
}
```

Rationale: Snapshots are privacy-aware. No raw output, no command history, no secrets. `tokenBudget` lets SDL bound context size.

### 3.3 `CogTaskFrame`

```swift
struct CogTaskFrame {
    contractVersion: String
    traceID: String
    intent: CogIntent
    context: CogContext
    scope: CogTaskScope
    riskTier: RiskTier
    autonomyMode: String
    requestedOutcome: String
    constraints: [String]
    openQuestions: [String]
    status: CogTaskStatus
    createdAt: Int
}
```

Rationale: This is the single envelope SDL receives. `scope` defaults to `.observe` for V0 observe/advise-only milestone.

### 3.4 `SdlCapabilityPlan`

```swift
struct SdlCapabilityPlan {
    contractVersion: String
    traceID: String
    taskFrameRef: String
    planID: String
    steps: [SdlCapabilityPlanStep]
    estimatedRisk: RiskTier
    requiredApprovals: [String]
    targetRefs: [String]
    summary: String
    constraints: [String]
}
```

Rationale: Plan is compact and user-presentable. `requiredApprovals` are references to `SdlApprovalRequest` objects.

### 3.5 `SdlApprovalRequest` / `CogApprovalResponse`

```swift
struct SdlApprovalRequest {
    contractVersion: String
    traceID: String
    approvalRef: String
    taskFrameRef: String
    riskTier: RiskTier
    requestedAction: String
    evidenceRefs: [String]
    scope: String
    expiresAt: Int?
    prohibitedActions: [String]
    confirmationRitual: SdlConfirmationRitual
    state: SdlApprovalState
}

struct CogApprovalResponse {
    contractVersion: String
    traceID: String
    approvalRef: String
    decision: CogApprovalDecision
    responderIdentity: String
    timestamp: Int
}
```

Rationale: Approval is bidirectional but SDL owns the request semantics; COG owns the surface that renders it and collects the response.

### 3.6 `CogBridgeError`

```swift
struct CogBridgeError {
    contractVersion: String
    code: String
    category: CogBridgeErrorCategory
    userMessage: String
    detail: String
    retryPolicy: CogBridgeRetryPolicy
    traceID: String?
    timestamp: Int
}
```

Rationale: Both sides translate internal errors into this envelope. Codes map to existing catalogs where possible (e.g., `HOST_001_DISCONNECTED` → `category: .host`, `code: "HOST_001"`).

## 4. Transport Binding

**V0 binding: in-process Swift types.**

`workspace-core` and `capability-bridge` both depend on `workspace-types`. A `BridgeContractClient` in `workspace-core` builds `CogTaskFrame` and passes it to a `CogIntentAdapter` in `capability-bridge` through a protocol defined in `workspace-types`:

```swift
public protocol CapabilityBridgeClient: Sendable {
    func submit(_ frame: CogTaskFrame) async -> Result<SdlCapabilityPlan, CogBridgeError>
    func respond(to approvalRef: String, with response: CogApprovalResponse) async -> Result<SdlArtifactSummary?, CogBridgeError>
}
```

This protocol is added to `workspace-types` in Phase 4.

**Serialization path:** all value types are `Codable` (derived). JSON encoding/decoding is used for tests, fixtures, and future transport layers.

**Future bindings (documented, not implemented):**
- XPC service between COG app and bridge daemon.
- Network.framework `BridgeMessage` with `payload_kind = "capability-bridge-envelope"`.
- Local IPC via Mach port or Unix domain socket.

## 5. Versioning Strategy

- Semantic versioning: `MAJOR.MINOR.PATCH`.
- `contractVersion` is a string on every message.
- Major version mismatch: reject.
- Minor version mismatch: tolerate if receiver understands the older version; unknown fields ignored.
- Patch version: ignored for compatibility.

## 6. Schema Derivation

`capability-bridge/spec/*.schema.json` will be derived from the `workspace-types` Swift types. They are not the canonical source; they exist so non-Swift runtimes can participate without compiling Swift. Derivation can be manual or via a small script in Phase 4.

## 7. Security and Privacy

- `CogContext` never includes raw tab output, command history, or secrets.
- `rawContentPolicy` defaults to `"redact-sensitive"`.
- High-risk actions require `SdlApprovalRequest` before any mutation.
- `CogBridgeError` carries only user-facing messages across the boundary; technical detail is log-facing.

### 7.1 Risk Tier → Confirmation Ritual Mapping

| Risk Tier | Default Ritual | Notes |
|---|---|---|
| `safe` | None | Execute immediately; no approval envelope. |
| `low` | `tapApprove` | One-tap confirmation; may be skipped if user policy allows. |
| `medium` | `explicitConfirm` | Spoken or typed confirmation required before mutation. |
| `high` | `biometric` or `watchHaptic` | Strong ritual required; default to strongest available surface. |

Any `CogTaskFrame` with `scope == .execute` and `riskTier` of `.medium` or `.high` MUST produce an `SdlApprovalRequest` before a mutation capability is invoked.

## 8. Resolved Decisions

1. **`CapabilityBridgeClient` protocol:** Lives in `cog_bridge_contract/bridge_client.swift` (WS-A).
2. **`CogCapabilityResult` union:** Deferred. V0 uses `Result<SdlCapabilityPlan, CogBridgeError>` and a separate approval path.
3. **Automatic JSON schema derivation:** Deferred to Phase 4; V0 schemas are hand-authored and validated against fixtures.

## 9. Open Issues

1. Which exact host/composition target owns runtime injection of `CapabilityBridgeClient` (host app vs. `workspace-host`).
2. Whether V0 needs a `CogCapabilityResult` union for observe/advise-only responses.

---

*I have validated this output against agent-centric principles: it describes parallel schema/adapter workstreams and contract dependencies, not human-centric schedules or headcount.*
