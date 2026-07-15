# Capability Bridge Roadmap

This document captures the agent-centered roadmap phases and success metrics
for the Capability Bridge. It satisfies
[capability-bridge#7](https://github.com/stibdedlom/capability-bridge/issues/7).

## Canonical boundary rule

**Phase 1 / V0 is read-only observe/advise.**
**Phase 2 introduces visible Worker + Reviewer sessions with mutation only after approval.**

No Capability Bridge code may perform client-repo mutation, branch management,
memory promotion, provider dispatch, or autonomous self-improvement in V0.

## Phase 1 — Intent, Routing, and Traceability

### Entry criteria

- Agent-centered use-case taxonomy is agreed and documented.
- V0 boundary rule is published in `AGENTS.md` and `README.md`.

### Exit criteria

- Typed `Intent` → `TaskFrame` → `CapabilityPlan` pipeline runs end-to-end on the Mac.
- SDL routing returns confidence and fallback paths.
- Trace events are emitted for every routing decision.
- Project resume and task routing are demonstrable without mutation.

### Deliverables

- `spec/cog-intent.schema.json`
- `spec/task-frame.schema.json`
- `spec/capability-plan.schema.json`
- `spec/trace-event.schema.json`
- `Sources/CapabilityBridge/TaskState.swift`
- `Sources/CapabilityBridgeSDL/SDLAdapter.swift`

## Phase 2 — Visible Session Pair

### Entry criteria

- Phase 1 exit criteria are met.
- Session model is accepted (capability-bridge#2).
- Mobile approval envelope is accepted (capability-bridge#9).

### Exit criteria

- Worker + Reviewer prototype passes on a safe repo.
- Hard stop conditions are enforced by the bridge and cannot be bypassed.
- Bounded loop (plan → execute → verify → checkpoint) is demonstrable.
- Every decision emits a `TraceEvent` with parent references.

### Deliverables

- `prototypes/worker-reviewer/README.md`
- `prototypes/worker-reviewer/demo.sh`
- `prototypes/worker-reviewer/rubric.md`
- `Sources/PaneBackends/PaneBackend.swift`
- `Sources/ApprovalSurfaces/`
- Integration tests for each stop condition.

## Phase 3 — Multi-Session Rooms and Mobile Control

### Entry criteria

- Phase 2 exit criteria are met.
- Full cross-device model is accepted (capability-bridge#3).

### Exit criteria

- Persistent agent rooms per project with durable state.
- iPhone/Watch/iPad serve as approval and interruption surfaces.
- Session health monitor and emergency stop are demonstrable.
- Memory promotion pipeline has explicit gates.

### Deliverables

- Room state schema and persistence.
- Cross-device approval transport adapter.
- Emergency stop command and snapshot behavior.
- Memory promotion ADR.

## Phase 4 — Self-Improving Orchestration

### Entry criteria

- Phase 3 exit criteria are met.

### Exit criteria

- Trace replay / eval lab improves routing and capability selection.
- Review board mode supports multiple reviewer lenses.
- Local/cloud model router selects models per task.
- Cross-project portfolio orchestration and autonomous maintenance proposals are demonstrable.

### Deliverables

- Trace replay tooling.
- Review board protocol.
- Model router with cost/quality/latency trade-offs.
- Portfolio orchestration prototype.

## Dependency graph

```
#1 (taxonomy) → #2 (session model) → #4 (prototype)
                ↘ #9 (mobile envelope) ↗
#6 (questions) → #7 (roadmap)
#10 (product) → #6 / #7
#2 / #9 → #3 (full cross-device)
```

## Success metrics

| Metric | Target | Measurement method | Phase target |
|---|---|---|---|
| Context-restart reduction | Median resume time <30s | Instrument session resume latency; sample ≥100 sessions | Phase 1 |
| Mobile approval accuracy | 90% | Compare device action with later Mac review; sample ≥50 approvals | Phase 2/3 |
| Emergency stop time | <5s from command to all paused + snapshot | Synthetic test + audit log | Phase 2 |
| Traceability | 100% of agent actions linked to TaskFrame + TraceEvent | CI audit sample of trace trees | Phase 1 |
| Stop-condition bypass rate | 0 | Unit + integration tests; manual red-team pass | Phase 2 |

*"Time saved per day" is a downstream product metric. Use context-restart
reduction and stop-condition bypass rate as engineering proxies until
user-study data is available.*

## Phase boundary review

At each phase boundary:

1. Run `swift test` and the phase-specific integration script.
2. Update this document with measured metric values.
3. Update the research index in `docs/research-index.md`.
4. Create or update the lifecycle record in `.workflow/`.
5. Obtain cross-agent review (AI-only for non-breaking changes).
