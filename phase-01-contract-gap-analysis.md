---
type: analysis
status: draft
created: 2026-06-27
task_ref: cog-bridge-contract-alignment
lifecycle_records:
  - workspace-core: 2da4239f-50fa-474f-962e-9b7d6cc3680f
  - workspace-types: b148d615-603f-4529-9494-7d292ebf6e1e
  - capability-bridge: 0c62d626-4500-4df3-9d44-1ef90e423873
---

# Phase 1 — Contract Gap Analysis

> Evidence-backed map of every touchpoint between COG (`workspace-core`) and SDL (`capability-bridge`) that needs a protocol.

## Executive Summary

COG and SDL are currently coupled through ad-hoc, repo-internal abstractions:

- `workspace-core` owns rich internal specs (`HostAdapter`, `API Contracts`, `Data Schema`) and a concrete Swift implementation (`CoreIntentHandler`, `TmuxAdapter`, etc.) that drives host operations directly.
- `workspace-types` owns the cross-repo Cocogiri contract (`Intent`, `Response`, `Event`, `Tab`, `RiskTier`, etc.) but it knows nothing about SDL governance semantics.
- `capability-bridge` owns the right SDL-shaped concepts (`TaskFrame`, `ContextBundle`, `CapabilityPacket`, `ApprovalRequest`, `TraceEvent`, `ArtifactSummary`, `PaneBackend`) but its JSON schemas are empty placeholders and its Swift types use raw `String` fields with no canonical mapping to COG types.

The result is a three-way mismatch: COG intent/context/status operations have no canonical mapping to SDL task frames and approval envelopes; schemas are duplicated-or-missing rather than referenced; and neither side can evolve independently. The first ratification step is to decide where the shared contract lives and then align every COG operation to an SDL concept through that contract.

## 1. COG Operations Inventory

The operations below currently bypass SDL governance. They are executed inside `workspace-core` against host adapters or internal state.

| # | COG Operation | Current Trigger | Current Consumer | Risk / Mutation |
|---|---|---|---|---|
| 1.1 | Voice intent intake | `VoiceSession` produces `Intent` | `CoreIntentHandler.handle(intent:)` | Low (parse only) |
| 1.2 | Target resolution | `Intent.targetQuery` + `WorkspaceModel` | `InputRouter` / `CoreIntentHandler` | Low |
| 1.3 | `send_input` | `Intent.action == .sendInput` | `HostAdapter.sendInput(tabID:text:)` | **High** (mutates tab) |
| 1.4 | `switch_tab` | `Intent.action == .switchTab` | `HostAdapter.switchTab(tabID:)` | Low |
| 1.5 | `read_output` | `Intent.action == .readOutput` | `HostAdapter.readOutput(tabID:offset:limit:)` | Low |
| 1.6 | Risk-tier enforcement | `CoreIntentHandler.riskTier(for:)` | `Response.confirmation` | Medium/High gate |
| 1.7 | Approval request/response | `IntentConfirmation` prompt → user confirm | `CoreIntentHandler` | Medium/High gate |
| 1.8 | Note capture | `Intent.action == .annotate` / `.takeNote` | `NoteStore.save(note:)` | Low |
| 1.9 | Status aggregation | `StatusAggregator` polls `WorkspaceModel` | `StatusBriefBuilder`, `RuleEngine` | Low |
| 1.10 | Rule engine alerts | Status change event | `VoiceOutput.alert/displayBrief` | Low |
| 1.11 | Session collapse/restore | User save/load session | `SessionCollapse.snapshot/restore` | Low |

Sources:
- `workspace-core/specs/interfaces/api-contracts.md`
- `workspace-core/specs/interfaces/host-adapter.md`
- `workspace-core/specs/interfaces/input-routing.md`
- `workspace-core/specs/data/schema.md`
- `workspace-core/specs/behavior/state-machines.md`
- `workspace-core/Sources/WorkspaceCore/intent_handler.swift`
- `workspace-core/Sources/WorkspaceCore/host_adapter/tmux_adapter.swift`

## 2. SDL Concept Inventory

The concepts below are declared in `capability-bridge` but are not yet mapped to COG operations.

| Concept | Purpose | Current Shape | Gap |
|---|---|---|---|
| `TaskFrame` | Intake artifact for a unit of work | `taskRef`, `userGoal`, `sourceIntent`, `workspaceTarget`, `repoContext`, `riskTier: String`, `autonomyMode: String`, `requestedOutcome`, `constraints`, `status`, `openQuestions` | No mapping from `workspace-types.Intent`; raw strings instead of typed enums |
| `ContextBundle` | Bounded context package with provenance | `workspaceSnapshot`, `noteRefs`, `memorySnippets`, `artifactRefs`, `aurRefs`, `omissions`, `freshness`, `tokenBudget`, `rawContentPolicy` | No producer in COG; COG assembles tab/surface state inline |
| `CapabilityPacket` | Request from bridge to SDL capability layer | `mode`, `selectedCapability`, `invocationMode`, `inputs`, `contextBundleRef`, `authorityScope`, `allowMutation`, `expectedOutputs` | No clear boundary with COG intent actions |
| `ApprovalRequest` | Human decision envelope for risky actions | `riskTier: String`, `requestedAction`, `evidenceRefs`, `scope`, `expiresAt`, `prohibitedActions`, `confirmationRitual`, `approvalState` | COG uses `IntentConfirmation` (prompt + intent) instead |
| `TraceEvent` | Append-only correlation record | `eventType`, `traceId`, `parentEventId`, `subjectRef`, `status`, `outcome`, `payloadSummary`, `payloadHash`, `artifactRefs`, `approvalRefs` | COG uses `Event` bus with no trace/parent correlation |
| `ArtifactSummary` | Compact result for user display | `artifactRef`, `artifactType`, `pathOrURI`, `fingerprint`, `producerCapability`, `title`, `summary`, `conformanceSummary`, `redactionState` | COG `Response`/`StatusBrief` carry unstructured text |
| `PaneBackend` | Visible agent session backend | `spawnSession`, `sendInput`, `readOutput`, `stopSession`, `listSessions` | COG uses `HostAdapter` which includes discovery, health, capabilities |

Sources:
- `capability-bridge/spec/README.md`
- `capability-bridge/spec/*.schema.json` (currently empty placeholders)
- `capability-bridge/Sources/CapabilityBridge/CapabilityBridge.swift`
- `capability-bridge/Sources/CapabilityBridge/PaneBackend.swift`
- `capability-bridge/Sources/CapabilityBridge/TaskState.swift`

## 3. COG → SDL Mapping

| COG Operation (§1) | Closest SDL Concept (§2) | Mapping Notes |
|---|---|---|
| 1.1 Voice intent intake | `TaskFrame` | `Intent.action` + `targetQuery` + `parameters` → `userGoal`, `workspaceTarget`, `requestedOutcome` |
| 1.2 Target resolution | `TaskFrame.workspaceTarget` + `ContextBundle.workspaceSnapshot` | `TargetResolution` (single/ambiguous/none) needs SDL representation |
| 1.3 `send_input` | `CapabilityPacket` to SDL worker executor, or `PaneBackend.sendInput` | High-risk; must route through `ApprovalRequest` |
| 1.4 `switch_tab` | `CapabilityPacket` / `HostAdapter.switchTab` | Surface control stays COG-owned; SDL may request it via plan |
| 1.5 `read_output` | `CapabilityPacket` → `ArtifactSummary` (paginated via `Chunk`) | COG `Chunk` has `index`/`hasMore`; SDL result should preserve pagination |
| 1.6 Risk-tier enforcement | `TaskFrame.riskTier` + `ApprovalRequest.riskTier` | COG `RiskTier` enum must be shared |
| 1.7 Approval request/response | `ApprovalRequest` / `ApprovalResponse` | Replace `IntentConfirmation` with SDL envelope |
| 1.8 Note capture | `ContextBundle.noteRefs` + `ArtifactSummary` | Note becomes a referenced artifact |
| 1.9 Status aggregation | `ContextBundle.workspaceSnapshot` + `TraceEvent` | Status brief feeds SDL context |
| 1.10 Rule engine alerts | `TraceEvent` | Alert becomes trace + plan |
| 1.11 Session collapse/restore | SDL lifecycle records + `TraceEvent` | Session snapshot references SDL task refs |

## 4. Mismatches, Gaps, and Overloads

### 4.1 Schema ownership is undefined
- **Evidence:** `capability-bridge/spec/*.schema.json` are empty placeholders; `workspace-types/contract.md` is concrete but SDL-agnostic; `workspace-core/specs/` describe internal interfaces.
- **Options:**
  - A: Schemas live in `capability-bridge/spec/` and `workspace-core` references them.
  - B: New shared `cocogiri-stibdedlom-contract` repository.
  - C: Schemas live in `workspace-types` since it is the designated contract boundary for Cocogiri.
- **Recommendation:** **Option C**. `BOUNDARY.md` states: "Cross-repo type definitions, shared protocols, public API contracts → `workspace-types`." `REGISTRY.yml` designates `repo.workspace-types` as "the integration surface" and "shared types, protocols, public API contracts." Both `workspace-core` and `capability-bridge` should consume the same `workspace-types` package. This avoids duplication and keeps the existing dependency direction intact.
- **Decision note:** If cross-org coupling is a concern, `workspace-types` can be versioned and published independently; no new repo is required for V0.

### 4.2 `Intent` shape mismatch
- **Evidence:** `workspace-types.Intent` uses `Action` enum (`switchTab`, `sendInput`, etc.), `targetQuery: String?`, `parameters: [String: String]`; `capability-bridge.TaskFrame` uses `userGoal: String`, `sourceIntent: String`, `workspaceTarget: String?`, `requestedOutcome: String`, `constraints: [String]`.
- **Gap:** No canonical transform from COG `Intent` to SDL `TaskFrame`.
- **Decision:** Add `CogIntent` / `CogTaskFrame` types in `workspace-types` that bridge the two shapes. `CogIntent` is a COG-native intent with locale/confidence/transcription; `CogTaskFrame` wraps intent + `CogContext` + approval envelope + trace ID.

### 4.3 Risk tier is a string in SDL
- **Evidence:** `capability-bridge.TaskFrame.riskTier: String`, `ApprovalRequest.riskTier: String`; `workspace-types.RiskTier` is a typed enum (`safe`, `low`, `medium`, `high`).
- **Gap:** Type safety and canonical values are lost at the SDL boundary.
- **Decision:** Use `workspace-types.RiskTier` in all cross-boundary messages; bridge adapters translate internal strings to the enum at their perimeter.

### 4.4 Context bundle has no producer in COG
- **Evidence:** `ContextBundle.workspaceSnapshot` is a `String?`; COG assembles `Tab[]`, `Surface[]`, `Host[]` in `WorkspaceModel`.
- **Gap:** COG does not produce a bounded, privacy-aware context package for SDL.
- **Decision:** Add `BridgeContextProvider` in `workspace-core` that assembles `CogContext` (typed surfaces/tabs/read-state/active device/transport path) without leaking internals. SDL receives a `ContextBundle` derived from `CogContext`.

### 4.5 Approval models differ
- **Evidence:** COG `IntentConfirmation` is prompt + intent; SDL `ApprovalRequest` is risk tier + evidence refs + scope + ritual + state.
- **Gap:** COG cannot render SDL approval requests; SDL cannot consume COG confirmations.
- **Decision:** Replace COG-internal approval with SDL `ApprovalRequest`/`ApprovalResponse` envelopes. COG renders the request; SDL owns the decision semantics.

### 4.6 Events vs. trace events
- **Evidence:** COG `Event` bus has `TabDiscoveredEvent`, `StatusChangedEvent`, etc.; SDL `TraceEvent` has `traceId`, `parentEventId`, `payloadHash`, `artifactRefs`.
- **Gap:** COG events are not emitted into SDL lifecycle records.
- **Decision:** Add `TraceEventEmitter` adapter in `capability-bridge` that subscribes to COG events (via `CogTraceEvent`) and writes SDL `TraceEvent`s.

### 4.7 Pane backend vs. host adapter
- **Evidence:** `HostAdapter` has `initialize`, `shutdown`, `healthCheck`, `discoverTabs`, `subscribeStatusChanges`, `sendInput`, `switchTab`, `closeTab`, `readOutput`, `getCapabilities`; `PaneBackend` has `spawnSession`, `sendInput`, `readOutput`, `stopSession`, `listSessions`.
- **Gap:** `PaneBackend` is narrower and session-oriented; it does not cover discovery, health, or status push.
- **Decision:** Keep `HostAdapter` as the COG-owned host surface. `capability-bridge` consumes `CogContext` (which includes host summaries) and uses `PaneBackend` only for SDL-managed visible sessions. Do not replace `HostAdapter` with `PaneBackend`; instead document the mapping.

### 4.8 Error envelope missing
- **Evidence:** `workspace-core/specs/behavior/error-catalog.md` defines `VALIDATION_001`, `HOST_001`, `RISK_001`, etc.; `capability-bridge` has no shared error envelope.
- **Gap:** COG and SDL cannot exchange canonical failures.
- **Decision:** Add `CogBridgeError` to `workspace-types` with `code`, `category`, `retryPolicy`, `userMessage`, `detail`. Map COG `CoreError`/`HostAdapterError` and SDL failures into this envelope.

### 4.9 Versioning is absent or implicit
- **Evidence:** `workspace-types/contract.md` says "should be versioned once it stabilizes"; `capability-bridge` schemas have no `contract_version`; `HostAdapter.contract_version` exists but is not connected to SDL.
- **Gap:** Neither side can negotiate protocol compatibility.
- **Decision:** Every cross-boundary message carries `contractVersion: String` starting with `"0.2.0"` for this ratification.

### 4.10 Transport binding undefined
- **Evidence:** COG uses `Network.framework` `BridgeMessage` for cross-device transport; SDL bridge has no transport contract.
- **Gap:** It is unspecified how `CogTaskFrame` physically reaches `capability-bridge`.
- **Decision:** V0 uses in-process Swift types (shared via `workspace-types`) with a serialization path defined. IPC/XPC or `BridgeMessage` payload binding is deferred but documented as a future transport option.

## 5. Canonical Schema Ownership Decision

**Chosen option: C — schemas live in `workspace-types`.**

Justification:
- `BOUNDARY.md` §Boundary Rules: "Cross-repo type definitions, shared protocols, public API contracts → `workspace-types`."
- `REGISTRY.yml` `repo.workspace-types`: "Shared types, protocols, public API contracts" and "The integration surface. External consumption and cross-repo integration happen at this contract boundary, versioned semantically."
- `workspace-core` already depends only on `workspace-types`; adding `capability-bridge` as a consumer preserves the one-way dependency graph.
- Avoids a new repository (Option B) for V0 and avoids placing Cocogiri-agnostic SDL schemas inside `capability-bridge/spec/` (Option A) where they would duplicate or drift from `workspace-types`.

Implications:
- `workspace-types` gains a new `cog_bridge_contract/` module with `CogIntent`, `CogContext`, `CogTaskFrame`, `SdlCapabilityPacket`, `SdlCapabilityPlan`, `SdlArtifactSummary`, `SdlApprovalRequest`, `CogApprovalResponse`, `CogTraceEvent`, `CogPaneBackendEvent`, and `CogBridgeError`.
- `capability-bridge` adds a dependency on `workspace-types` and removes raw strings in favor of the shared types.
- `capability-bridge/spec/*.schema.json` becomes a derived/secondary representation generated from `workspace-types` or kept as JSON Schema wrappers referencing the canonical contract version.
- `workspace-core` continues to depend only on `workspace-types`; it does not import `capability-bridge`.

## 6. Phase 2 Acceptance Criteria (from BASE Review)

1. Add `CogTargetQuery` and `CogTargetResolution` types to the `workspace-types` bridge module; ambiguity/single/none resolution is a first-class contract concern.
2. Define the in-process adapter surface and serialization path explicitly; transport binding should not remain indefinitely deferred.
3. Add `contractVersion: String` to every cross-boundary message; reconcile `"0.2.0"` with `HostAdapter.contract_version "0.1.0"` and the workspace-types semantic-versioning plan.
4. Keep SDL-specific concepts in a dedicated `cog_bridge_contract` namespace inside `workspace-types`; do not leak them into core `Intent`/`Response` types.
5. Derive `capability-bridge/spec/*.schema.json` from `workspace-types` rather than leaving them as empty placeholders.
6. Map `PaneBackendError` into the shared `CogBridgeError` envelope.

## 7. Open Questions for Phase 2

1. Should `CogIntent` reuse the existing `workspace-types.Intent` type or be a parallel SDL-facing intent? Reuse risks SDL-specific fields leaking into the voice/core boundary; parallel types risk duplication.
2. Should `CogContext` include raw tab output snippets, or only metadata + refs? Privacy/classification policy must be explicit.
3. How does `CogTraceEvent` relate to the existing `workspace-types.Event` enum? Is it a wrapper, a superset, or a separate stream?
4. What is the canonical `contractVersion` value? Proposed `"0.2.0"` to mark this ratification, but must align with semantic-versioning plan.

---

*I have validated this output against agent-centric principles: it describes parallel schema/adapter workstreams and contract dependencies, not human-centric schedules or headcount.*
