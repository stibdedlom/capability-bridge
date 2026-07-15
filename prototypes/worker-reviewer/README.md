# Worker + Reviewer Visible Session Pair Prototype

This prototype demonstrates the first Capability Bridge Phase 2 feature:
a visible Worker + Reviewer session pair spawned from one `TaskFrame`,
with mobile approval.

It satisfies the planning and scaffolding acceptance criteria of
[capability-bridge#4](https://github.com/stibdedlom/capability-bridge/issues/4).
The executable end-to-end implementation is staged behind open dependencies
#1, #2, and #9, which are tracked in `docs/research-index.md`.

## Safe target repo

This prototype runs against `stibdedlom/capability-bridge` itself:

- Public or non-production.
- Free of secrets, deploy pipelines, and external API calls.
- Revertible in under 5 minutes (`git checkout main`).
- Changes are limited to `prototypes/worker-reviewer/` and documentation.

## Prototype scope

1. User creates a `TaskFrame` in COG via text. *(Voice-initiated framing is a Phase 3+ stretch goal.)*
2. Bridge asks SDL for routing; SDL selects Worker and Reviewer capabilities.
3. Bridge spawns two visible sessions: Worker and Reviewer in separate panes/windows using the `PaneBackend` protocol.
4. Worker proceeds in a bounded loop: plan → execute → verify → checkpoint.
5. Reviewer critiques at checkpoints and can force a stop or request human review by emitting an `ApprovalRequest`.
6. At a checkpoint or risky action, the bridge sends an `ApprovalRequest` to a Mac-local notification or a paired iPhone/Watch.
7. User approves, redirects, or stops; the bridge updates state and emits `TraceEvent`s.

## Stop conditions

The Worker must pause on:

- Unapproved file mutation.
- Scope change detected in the `TaskFrame`.
- Risky command class (destructive, network, or spend-related).
- Three consecutive verification or tool failures.
- Explicit user pause.

## Files

- `README.md` — this file
- `demo.sh` — scripted walkthrough of the Worker/Reviewer/Approval flow
- `rubric.md` — evaluation rubric for the prototype
- `fixtures/` — sample `TaskFrame`, `ApprovalRequest`, and `TraceEvent` JSON

## Run the demo

```bash
./prototypes/worker-reviewer/demo.sh
```

The demo is a textual simulation. It does not spawn real terminal panes or
send actual mobile notifications; those require the dependencies listed below.

## Dependencies

- [capability-bridge#1](https://github.com/stibdedlom/capability-bridge/issues/1) — Agent-centered use-case taxonomy
- [capability-bridge#2](https://github.com/stibdedlom/capability-bridge/issues/2) — Visible-session orchestration model
- [capability-bridge#9](https://github.com/stibdedlom/capability-bridge/issues/9) — Phase 2 mobile approval envelope

Once these issues are closed, this prototype can be promoted to a Swift
executable that uses the real `PaneBackend` and `ApprovalSurface` adapters.

## Evaluation

See `rubric.md` for the evaluation rubric.
