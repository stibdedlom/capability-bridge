---
type: plan
status: draft
created: 2026-06-27
task_ref: cog-bridge-contract-alignment
lifecycle_records:
  - workspace-core: 2da4239f-50fa-474f-962e-9b7d6cc3680f
  - workspace-types: b148d615-603f-4529-9494-7d292ebf6e1e
  - capability-bridge: 0c62d626-4500-4df3-9d44-1ef90e423873
contract_version: "0.2.0"
---

# Phase 3 — Implementation Plan

> Agent-centric, parallel workstreams for ratifying and implementing the COG-SDL bridge contract.

## Executive Summary

Implementation is split into five independent workstreams. The dependency order is strict: contract publication (WS-A) must land in `workspace-types` before `capability-bridge` (WS-B) or `workspace-core` (WS-C) can consume it. Tests (WS-D) and documentation (WS-E) run in parallel once the contract is stable. The V0 milestone is **observe/advise only**: COG can send an intent, the bridge returns a plan or approval request, and COG displays it. No autonomous execution in V0.

## Cross-Repo Dependency Order

1. `workspace-types` contract changes (WS-A)
2. `capability-bridge` reference implementation (WS-B)
3. `workspace-core` contract consumer implementation (WS-C)
4. Integration tests and fixtures (WS-D)
5. Documentation and registry updates (WS-E)

## Workstreams

### WS-A — Contract Schema Finalization and Publication

**Owner:** `workspace-types` worktree.

**Files to create/modify:**
- `Sources/WorkspaceTypes/cog_bridge_contract/bridge_client.swift` — new `CapabilityBridgeClient` protocol.
- `Sources/WorkspaceTypes/cog_bridge_contract/*.swift` — add `contractVersion` constants if needed; verify `Codable` derivation for serializable types.
- `Tests/WorkspaceTypesTests/BridgeContractTests.swift` — new tests for Sendable/Equatable and JSON round-trips.
- `capability-bridge/spec/*.schema.json` — derive JSON Schema wrappers from `workspace-types` types.

**Dependencies:** None. This workstream produces the contract consumed by WS-B and WS-C.

**Tests that must pass:**
- `swift build` and `swift test` in `workspace-types`.
- New bridge-contract tests compile and pass.
- JSON schema files validate against sample fixtures.

**Risk and rollback:**
- Risk: Adding too many SDL-specific fields into `workspace-types` could blur the boundary.
- Mitigation: Keep types in the dedicated `cog_bridge_contract` module; do not modify core `Intent`/`Response`.
- Rollback: Revert the `cog_bridge_contract` directory and `contract.md` update.

### WS-B — Capability Bridge Reference Implementation

**Owner:** `capability-bridge` worktree.

**Files to create/modify:**
- `Package.swift` — add `workspace-types` dependency and import it in relevant targets.
- `Sources/CapabilityBridge/CapabilityBridge.swift` — refactor existing `TaskFrame`, `ContextBundle`, `CapabilityPacket`, `ApprovalRequest`, `TraceEvent`, `ArtifactSummary` to use `workspace-types` equivalents; remove raw strings.
- `Sources/CapabilityBridgeCOG/CogIntentAdapter.swift` — replace placeholder; accepts `CogIntent`/`CogTaskFrame`, emits SDL packet/plan.
- `Sources/CapabilityBridgeCOG/CogContextBundleBuilder.swift` — new; builds bounded `ContextBundle` from `CogContext`.
- `Sources/CapabilityBridgeSDL/SDLAdapter.swift` — replace placeholder; routes packets to SDL capabilities and returns plans/artifacts.
- `Sources/CapabilityBridgeSDL/CapabilityPlanResponder.swift` — new; returns `SdlCapabilityPlan` and `SdlApprovalRequest` envelopes back to COG.
- `Sources/CapabilityBridgeSDL/TraceEventEmitter.swift` — new; writes `CogTraceEvent`s into SDL lifecycle records.
- `Sources/PaneBackends/CogPaneBackend.swift` — new protocol and tmux reference implementation that maps to `HostAdapter` via `workspace-types` protocols. V0 is observe/advise-only: no execute path is introduced.
- `Sources/PaneBackends/MockPaneBackend.swift` — update to conform.
- `AGENTS.md` — update contract boundary notes.

**Dependencies:** WS-A must be merged or the local workspace-types dependency must point to the worktree.

**Tests that must pass:**
- `swift build` and `swift test` in `capability-bridge`.
- CogIntentAdapter unit tests.
- TraceEventEmitter tests.
- PaneBackend mock tests.

**Risk and rollback:**
- Risk: `capability-bridge` may depend on `workspace-types` features not yet published.
- Mitigation: Use a local path dependency during development; switch to versioned dependency before PR.
- Rollback: Remove `workspace-types` dependency and restore raw-string types.

### WS-C — Workspace Core Contract Consumer Implementation

**Owner:** `workspace-core` worktree.

**Files to create/modify:**
- `Package.swift` — ensure `workspace-types` dependency is current; do NOT add `capability-bridge` dependency.
- `Sources/WorkspaceCore/bridge/BridgeContractClient.swift` — new; shapes internal intents into `CogIntent`/`CogTaskFrame`.
- `Sources/WorkspaceCore/bridge/BridgeContextProvider.swift` — new; assembles `CogContext` from `WorkspaceModel` without leaking internals.
- `Sources/WorkspaceCore/bridge/BridgeApprovalPresenter.swift` — new; renders `SdlApprovalRequest` and returns `CogApprovalResponse`.
- `Sources/WorkspaceCore/bridge/BridgeErrorTranslator.swift` — new; maps `CoreError`/`HostAdapterError` to `CogBridgeError`.
- `Sources/WorkspaceCore/intent_handler.swift` — refactor `InputRouter`/`CoreIntentHandler` so high-level intents can route either to existing `HostAdapter` path or new bridge path, gated by a feature flag or build setting.
- `AGENTS.md` — update if bridge consumer rules are needed.

**Dependencies:** WS-A. WS-B for integration but not for compilation (bridge client is protocol-based).

**Tests that must pass:**
- `swift build` and `swift test` in `workspace-core`.
- BridgeContextProvider privacy tests (assert no raw output, command history, or secrets in `CogContext` serialization).
- Boundary test: serialize a maximally populated `CogIntent` and assert `sourceIntent` does not leak host-adapter internals or unbounded payloads.
- BridgeErrorTranslator tests: confirm `detail` is log-facing only and `userMessage` never forwards internal host error strings.
- Feature-flag routing tests.

**Risk and rollback:**
- Risk: Refactoring `InputRouter` could break existing host-adapter journeys.
- Mitigation: Default routing remains host-adapter-first; bridge path is opt-in via feature flag.
- Rollback: Disable bridge flag and revert bridge source files.

### WS-D — Tests & Fixtures

**Owner:** All three code worktrees plus a new integration fixture.

**Files to create/modify:**
- `workspace-types/Tests/WorkspaceTypesTests/BridgeContractTests.swift` — schema/round-trip tests.
- `capability-bridge/Tests/CapabilityBridgeTests/BridgeContractAdapterTests.swift` — adapter tests.
- `workspace-core/Tests/WorkspaceCoreTests/BridgeConsumerTests.swift` — consumer tests.
- `capability-bridge/Tests/CapabilityBridgeTests/IntegrationFixture.swift` or new `Tests/CapabilityBridgeIntegrationTests/` — end-to-end fake COG + fake SDL + bridge.

**Integration fixture loop:**
1. Fake COG surface with one tab.
2. Fake SDL capability that echoes or approves.
3. Bridge in the middle.
4. Assert: intent → plan → approval → result completes end-to-end.

**Dependencies:** WS-A, WS-B, WS-C.

**Tests that must pass:**
- JSON schema validation tests.
- Round-trip tests: COG intent → bridge → SDL packet → bridge → COG plan.
- Error translation tests.
- Pane backend mock tests.
- Approval timeout/retry tests.
- Boundary/privacy serialization tests for `CogIntent.sourceIntent` and `CogContext`.
- Integration fixture proves end-to-end loop.

**Advanced cases to cover or defer:**

| Case | Test or Deferral | Rationale |
|---|---|---|
| Multiple concurrent tabs with same name | Covered | Target resolution ambiguity must be exercised. |
| High-risk command requiring Watch approval while user offline | Covered | Approval timeout + deferred state. |
| Capability routing failure / ambiguous intent | Covered | Bridge returns `CogBridgeError` with `.capability` category. |
| Pane backend that does not support status push | Covered | Mock backend exposes capability negotiation. |
| Transport path switch mid-session (Bonjour → iCloud) | Deferred | V0 is in-process; document in migration guide. |
| Session collapse/restore with pending SDL tasks | Deferred | V0 observe/advise only; no pending execution. |
| Multilingual intent with mixed-language context | Covered | `CogIntent.locale` + `transcription` fixtures. |

### WS-E — Documentation and Registry Updates

**Owner:** `cocogiri-meta` and code worktrees.

**Files to create/modify:**
- `workspace-core/docs/cog-bridge-contract.md` — protocol reference.
- `workspace-core/docs/migration-host-adapter-to-bridge.md` — how `HostAdapter` maps to new contract.
- `capability-bridge/docs/architecture/cog-bridge-contract.md` — SDL-side protocol reference.
- `cocogiri-meta/REGISTRY.yml` — add new document IDs if needed.
- `cocogiri-meta/Children/README.md` or `Children/` docs if phase status changes.
- `cocogiri-meta/BOUNDARY.md` — update if contract boundary rules need clarification.

**Dependencies:** WS-A, WS-B, WS-C.

**Tests that must pass:**
- `python3 scripts/registry-drift-check.py` after `REGISTRY.yml` changes.
- `swift build` and `swift test` in `workspace-core` and `capability-bridge` after doc changes that touch code comments.

## Runtime Wiring

`workspace-core` holds a `CapabilityBridgeClient` reference defined in `workspace-types`; `capability-bridge` provides a concrete conformance. The host app / `workspace-host` composition layer injects the conformance at runtime so that `workspace-core` never imports `capability-bridge`. This wiring layer is documented in `workspace-core/docs/migration-host-adapter-to-bridge.md` and exercised in the WS-D integration fixture.

## Minimal V0 Slice

The first milestone is **observe/advise only**:

1. COG receives voice/text intent.
2. `BridgeContractClient` shapes it into `CogTaskFrame` with `scope: .observe` or `.advise`.
3. `CogIntentAdapter` in `capability-bridge` receives the frame.
4. Bridge returns `SdlCapabilityPlan` (and `SdlApprovalRequest` if risk requires).
5. COG displays the plan/approval request.
6. No host mutation occurs without explicit user approval and `scope: .execute`, which is gated out of V0.

## SDL Lifecycle Integration

- Every workstream commits with lifecycle record IDs in messages.
- WS-A, WS-C, WS-D, WS-E OOB records live in `cocogiri-meta` (`2da4239f` for workspace-core, `b148d615` for workspace-types).
- WS-B record lives in `capability-bridge` (`0c62d626`).
- Cross-repo dependency order is enforced by build/test order, not just process.
- `.workflow/reviews/` collect sibling-agent reviews per phase.

## Task Graph

See `TASK_GRAPH.md` for the parallel workstream visualization.

## Quality Gates

- WS-A: `swift test` in `workspace-types` passes; schemas derived.
- WS-B: `swift test` in `capability-bridge` passes; no SDL internals leaked.
- WS-C: `swift test` in `workspace-core` passes; no `capability-bridge` import.
- WS-D: Integration fixture passes; advanced cases covered or explicitly deferred.
- WS-E: Registry drift check passes; docs lint clean.

---

*I have validated this output against agent-centric principles: it describes parallel workstreams, contract dependencies, and approval-gate quality checks, not human-centric schedules or headcount.*
