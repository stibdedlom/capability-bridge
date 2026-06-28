# ADR-071: Capability Bridge Phase 2 Approval Envelope

## Status
Proposed

## Context
Issue [#9](https://github.com/stibdedlom/capability-bridge/issues/9) defines the bridge-owned approval protocol for the Phase 2 Worker + Reviewer prototype. COG owns the human surface and transport (`cocogiri/workspace-core#5`, `#20`, `#21`, `#26`); the bridge owns the typed request/response contract, SDL lifecycle linkage, and the trace event emitted when an approval resolves.

The existing `spec/approval-response.schema.json` only models `approved`/`denied`/`deferred` and is missing the six Phase 2 outcomes, `surface_ref`, `resolved_at`, and conditional `new_scope`. `spec/approval-request.schema.json` is missing the `scope_hash` field required by the issue.

## Decision

1. The bridge defines `ApprovalRequest` and `ApprovalResponse` as the canonical contract between SDL-routed actions and COG approval surfaces.
2. `ApprovalResponse` supports six outcomes: `approve`, `reject`, `redirect`, `pause_all`, `resume_all`, `stop_all`.
3. Every response includes `request_id`, `task_frame_ref`, `decision`, `surface_ref`, and `resolved_at`; `reason` is optional; `new_scope` is required when `decision == redirect`.
4. `ApprovalRequest` includes a stable `scope_hash` computed over the approved scope.
5. Approval resolution emits a `TraceEvent` via `TraceEventEmitter` with the request, response, outcome, and SDL task reference. V0 persistence remains a no-op; tests assert the call path.
6. Bridge-side state transitions (`TaskPhase`) are updated to support `.paused` for `pause_all`/`resume_all` and terminal stop for `stop_all`.
7. High-risk mutation execution remains Mac/SDL-gated; mobile devices remain control surfaces only.

## Consequences
- COG can implement its own surface/transport without changing bridge contracts.
- SDL lifecycle records can reference approval outcomes through trace events.
- `approval-response.schema.json` contract version must bump to `0.3.0` because the shape changes.

## Alternatives considered
- Keep the existing `approved/denied/deferred` model — rejected: it cannot express redirect, pause, resume, or stop.
- Put approval outcomes in COG-owned types — rejected: violates Decision 004 boundary; the bridge owns the protocol envelope.

## References
- `docs/decisions/004-cog-bridge-boundary.md`
- `spec/approval-request.schema.json`
- `spec/approval-response.schema.json`
- `spec/trace-event.schema.json`
- Issue [#9](https://github.com/stibdedlom/capability-bridge/issues/9)
