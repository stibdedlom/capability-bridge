# Lane B Scope Review — Capability Bridge Phase 2 Approval Envelope

- **Worktree:** `/Users/vishalsingh/Documents/v-i-s-h-a-l/stibdedlom/capability-bridge-worktree-approval-envelope-phase2`
- **Branch:** `feature/bridge-approval-envelope-phase2`
- **Issue:** https://github.com/stibdedlom/capability-bridge/issues/9
- **Lifecycle record:** `.workflow/3fb96aba-0f48-40dd-8989-0e6d79afc0d1.json`
- **Reviewer role:** `capability-implementation-reviewer`
- **Date:** 2026-06-28

---

## 1. Summary of #9 and the COG/Bridge Boundary

**Issue #9** defines the *bridge-owned* approval-protocol envelope for the Phase 2 Worker + Reviewer prototype. The bridge must specify:

- The `ApprovalRequest` fields a risky SDL action carries.
- The `ApprovalResponse` fields COG returns for the six Phase 2 outcomes: `Approve`, `Reject`, `Redirect`, `PauseAll`, `ResumeAll`, `StopAll`.
- The `TraceEvent` emitted when an approval resolves.
- The SDL lifecycle/task-frame linkage for each outcome.

**Canonical boundary (docs/decisions/004-cog-bridge-boundary.md):**

- **COG / `cocogiri/workspace-core`** owns human-facing surfaces and transport: device UI, pairing, CloudKit, Bonjour/local transport, retry queues, biometric/hold-to-confirm rituals.
- **Capability Bridge** owns protocol translation and SDL orchestration: `ApprovalRequest`/`ApprovalResponse` contracts, trace-event emission, bridge-side interpretation of COG decisions, and coordination with SDL lifecycle/routing.

High-risk mutation execution remains Mac/SDL-gated; mobile devices are control surfaces only.

---

## 2. Proposed Bounded Implementation Scope

### Implement now (bridge-owned)

1. **Schema contracts**
   - Update `spec/approval-request.schema.json` to add the missing `scope_hash` field and ensure it already-required fields (`request_id`/`task_frame_ref`/`risk_tier`/`scope`/`expires_at`/`evidence_refs`) satisfy the issue.
   - Rewrite `spec/approval-response.schema.json` to model the six Phase 2 outcomes with `request_id`, `task_frame_ref`, `decision`, `surface_ref`, `resolved_at`, optional `reason`, and conditional `new_scope`.
   - Document approval-resolution trace requirements inside `spec/trace-event.schema.json` (event type, `approval_refs`, `payload_summary` convention, SDL task reference).
2. **Sample payloads & CI**
   - Add valid/invalid sample request/response JSON under `examples/` or `Tests/Fixtures/`.
   - Add a GitHub Actions workflow that validates the samples against `spec/*.schema.json` on every PR.
3. **Bridge-side state interpretation**
   - Extend `Sources/CapabilityBridge/TaskState.swift` (`TaskPhase`) with `.paused` if `PauseAll`/`ResumeAll` are supported.
   - Update `Sources/CapabilityBridgeSDL/SDLAdapter.swift` `respond(to:with:)` to map each decision to a task-phase transition and emit a trace event (still V0 no-op persistence, but the call path must exist).
   - Update `Sources/CapabilityBridgeSDL/CapabilityPlanResponder.swift` to generate `SdlApprovalRequest` values that include `scope_hash` and the new contract shape.
4. **Tests**
   - Add unit tests for each of the six decisions mapping to the correct `TaskPhase` / `StopSignal`.
   - Add schema-round-trip tests and sample-payload validation tests.

### Defer (COG-owned or future phases)

- iPhone/iPad/Watch/tvOS/Vision Pro approval UI.
- Device pairing, token storage, CloudKit records, Bonjour/local transport, retry queues, offline delivery.
- Biometric or hold-to-confirm surface rituals.
- Execution of approved high-risk mutations beyond bridge state transitions.
- Real persistence/redaction for `TraceEvent` (V0 remains no-op).
- Running agents on mobile devices.

---

## 3. File-Level Checklist

| File | Action | Notes |
|------|--------|-------|
| `spec/approval-request.schema.json` | Update | Add required `scope_hash`. Keep `request_id`/`task_frame_ref`/`risk_tier`/`scope`/`expires_at`/`evidence_refs`. Consider bumping `contract_version` to `0.3.0` because `scope_hash` is a breaking addition. |
| `spec/approval-response.schema.json` | Rewrite | Decision enum: `approve`, `reject`, `redirect`, `pause_all`, `resume_all`, `stop_all`. Required: `request_id`, `task_frame_ref`, `decision`, `surface_ref`, `resolved_at`. Optional: `reason`, `new_scope` (required when `decision == redirect`). |
| `spec/trace-event.schema.json` | Update | Add documentation/`$comment` for `approval_resolution` event type, `approval_refs` usage, and payload summary conventions. |
| `Sources/CapabilityBridge/TaskState.swift` | Extend | Add `.paused` to `TaskPhase`; ensure `StopSignal` covers policy/user/terminal stop cases. |
| `Sources/CapabilityBridgeSDL/SDLAdapter.swift` | Implement | Map each response decision to a phase transition and call `TraceEventEmitter`. Do not execute mutations. |
| `Sources/CapabilityBridgeSDL/CapabilityPlanResponder.swift` | Update | Build `SdlApprovalRequest` with `scope_hash` and the Phase 2 field set. |
| `Sources/CapabilityBridgeSDL/TraceEventEmitter.swift` | No functional change | Keep V0 no-op persistence, but ensure it is invoked from `SDLAdapter.respond`. |
| `Tests/CapabilityBridgeTests.swift` | Extend | Tests for all six outcomes, schema sample validation, and trace-event invocation. |
| `examples/` or `Tests/Fixtures/` | Add | Valid and invalid sample request/response payloads. |
| `.github/workflows/validate-schemas.yml` | Add | CI step to validate sample payloads against schemas (e.g., `check-jsonschema` or a Python `jsonschema` script). |
| `docs/decisions/004-cog-bridge-boundary.md` | Reference only | Already accepted; no edit required unless the implementer wants to add an explicit note about the six Phase 2 outcomes. |
| `registry/index.yaml` | Create | See Section 4. Required for lifecycle validation. |
| `.workflow/3fb96aba-0f48-40dd-8989-0e6d79afc0d1.json` | Update | Add `registry/index.yaml` to `preflight.touched_paths` and `authority_envelope.allowed_paths`. |

---

## 4. Resolving the Missing `registry/index.yaml`

**Current state:** `infra/scripts/lifecycle/validate-record.sh` fails with:

```
ERROR: declared capability 'capability-registry' not found in registry/index.yaml
```

because `capability-bridge` has no `registry/index.yaml` even though its lifecycle record declares `links.capability: capability-registry`.

### Options

1. **Create a local `registry/index.yaml` in `capability-bridge`.**
   - Copy or alias the `capability-registry` entry from `/Users/vishalsingh/Documents/v-i-s-h-a-l/stibdedlom/infra/registry/index.yaml`.
   - Update the lifecycle record to include `registry/index.yaml` in `touched_paths` and `allowed_paths`.
   - *Pros:* Works with the existing validation script; self-contained for this repo.
   - *Cons:* Duplicates a slice of company registry; must be kept in sync if the canonical entry changes.

2. **Patch `infra/scripts/lifecycle/validate-record.sh` to fall back to the company registry.**
   - When `$ROOT/registry/index.yaml` is absent, read from a known `INFRA_REGISTRY` path or environment variable.
   - *Pros:* Single source of truth; no per-repo duplication.
   - *Cons:* Changes shared governance tooling; requires APEX review; assumes the infra repo is present/known in CI.

3. **Symlink `capability-bridge/registry/index.yaml` to `infra/registry/index.yaml`.**
   - *Pros:* No duplication.
   - *Cons:* Relative path assumes the current sibling worktree layout; breaks in CI or other checkout structures.

4. **Add the `sandbox` flag to the lifecycle record to skip capability lookup.**
   - *Pros:* Fastest; no file needed.
   - *Cons:* Defeats governance; inappropriate for an execution record.

### Recommendation

**Option 1 — create a minimal local `registry/index.yaml`.** It satisfies `validate-record.sh` without modifying shared tooling and keeps the bridge repo independently validatable. The file should contain only the `capability-registry` entry the lifecycle record needs, with a comment pointing to the canonical source in `stibdedlom/infra`.

The lifecycle record must then be updated:

- `preflight.touched_paths` includes `registry/index.yaml`.
- `authority_envelope.allowed_paths` includes `registry/`.

Because `registry/*` paths already derive to tier 2 and reviewers `BASE APEX`, this does not change the required reviewer set or tier.

---

## 5. Risks / Guardrails

- **Contract-version breakage.** Adding `scope_hash` and reshaping `approval-response` is a breaking change from the current `0.2.0` envelope. Either bump the schema `contract_version` to `0.3.0` and update the `WorkspaceTypes` dependency branch accordingly, or split the new bridge response into a separate schema file. Do not silently change `0.2.0` semantics.
- **COG boundary creep.** Any code that touches CloudKit, device pairing, surface UI, biometric rituals, or local transport is out of scope and must be rejected in review.
- **Pause/Resume semantics.** `PauseAll`/`ResumeAll` must only mutate bridge `TaskState`; they must not invoke SDL execution or send device commands.
- **Redirect execution risk.** `Redirect` reframes the task scope and routes back through the planner; it must not execute the new scope immediately.
- **Trace-event persistence.** The V0 emitter is intentionally no-op. Tests may assert that it is called, but not that events are persisted.
- **High-risk mutations.** Keep high-risk actions Mac/SDL-gated; do not expand mobile approval authority in this issue.
- **Schema drift with `WorkspaceTypes`.** The Swift types (`CogApprovalResponse`, `SdlApprovalRequest`, etc.) come from the external `workspace-types` package. Coordinate schema changes with that package's `feature/cog-bridge-contract-alignment` branch or tests will fail to compile.

---

## 6. Recommended Validation Commands

Run these before marking the issue complete:

```bash
# Swift build & test
swift build
swift test

# Lifecycle record validation (requires the registry/index.yaml fix from Section 4)
/Users/vishalsingh/Documents/v-i-s-h-a-l/stibdedlom/infra/scripts/lifecycle/validate-record.sh \
  --base origin/main \
  --branch feature/bridge-approval-envelope-phase2

# Whitespace / merge-conflict check
git diff --check

# Schema validation (add to CI; example using check-jsonschema)
pip install check-jsonschema
check-jsonschema --schemafile spec/approval-request.schema.json examples/approval-request-valid.json
check-jsonschema --schemafile spec/approval-response.schema.json examples/approval-response-approve.json

# Local registry sanity check (after creating registry/index.yaml)
python3 -c "import yaml; yaml.safe_load(open('registry/index.yaml'))"
```

**Current baseline (as of this review):**

- `swift build` ✅ passes
- `swift test` ✅ passes (10 tests)
- `validate-record.sh` ❌ fails until `registry/index.yaml` is added
- `git diff --check` ✅ clean

---

## 7. Go / No-Go Recommendation

**Conditional GO — with blockers.**

The bounded scope is clear and aligned with Decision 004. Implementation may proceed **only after**:

1. `registry/index.yaml` is created (Section 4) and the lifecycle record is updated to include it.
2. The schema changes in Section 3 are accepted and matched in `WorkspaceTypes` if needed.
3. A schema-validation CI step is added and sample payloads are provided.

If those blockers remain unresolved, the branch cannot pass lifecycle validation or acceptance criteria, so the recommendation becomes **No-Go for merge**.

Do not expand this issue into COG surfaces, transport, or mobile execution.
