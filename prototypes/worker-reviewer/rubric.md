# Worker + Reviewer Prototype Evaluation Rubric

| Criterion | Weight | Pass threshold | Evidence |
|---|---|---|---|
| Given a `TaskFrame`, the bridge spawns Worker and Reviewer sessions on the configured `PaneBackend`; both are listed by a `bridge sessions` command. | 20% | Demo script lists Worker and Reviewer sessions. | `demo.sh` output |
| Worker loop pauses on unapproved mutation, scope change, risky command class, three consecutive failures, and explicit pause. | 20% | Demo script demonstrates each pause trigger in text. | `demo.sh` output + `fixtures/` |
| Reviewer emits an `ApprovalRequest`; bridge transitions Worker to `paused` until `ApprovalResponse`. | 20% | `approval-request.json` fixture is emitted and state transition is logged. | `fixtures/approval-request.json` + `demo.sh` |
| Approval surface presents approve/reject/redirect/stop actions and routes response back. | 15% | Demo script shows Mac/iPhone/Watch options and selected response. | `demo.sh` output |
| Every approval, redirect, stop, scope change, and checkpoint emits a `TraceEvent` linking to parent `TaskFrame` and prior `TraceEvent`. | 15% | `trace-event.json` fixture links to TaskFrame and prior trace. | `fixtures/trace-event.json` |
| Prototype runs against a documented safe repo with revertible changes. | 5% | README names `stibdedlom/capability-bridge` as target and `git checkout main` as rollback. | `README.md` |
| Demo script and rubric are present. | 5% | `demo.sh` and `rubric.md` exist and run without errors. | This file and `demo.sh` |

## Scoring

- **90–100%:** Prototype is ready for promotion to Swift executable once #1, #2, #9 close.
- **70–89%:** Prototype is structurally sound; add missing fixtures or clarify boundaries.
- **<70%:** Revisit scope and dependencies before claiming Phase 2 exit.

## Current assessment

This scaffolding meets the documentation and simulation criteria. The
executable pane and mobile-surface integrations are explicitly deferred to
#1, #2, and #9.
