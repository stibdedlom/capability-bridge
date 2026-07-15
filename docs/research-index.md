# Capability Bridge Research Index

Master tracking index for Capability Bridge research and implementation.
Satisfies [capability-bridge#8](https://github.com/stibdedlom/capability-bridge/issues/8).

## Component issues

| Issue | Title | Phase | Status | Depends on | Blocks |
|---|---|---|---|---|---|
| #1 | Agent-centered use-case taxonomy | 1 | Open | #7 | #2 |
| #2 | Visible-session orchestration model | 2 | Open | #1, #7 | #4, #9 |
| #3 | Cross-device control surface model (Phase 3+) | 3 | Open | #9, #2 | — |
| #4 | First prototype: Worker + Reviewer visible session pair | 2 | Open | #1, #2, #7, #9 | — |
| #5 | Research sources and references | — | Open | — | — |
| #6 | Open questions and risks | Cross-phase | Open | #10 | #7 |
| #7 | Agent-centered roadmap and success metrics | Cross-phase | Closed | #6, #10 | #1, #2 |
| #9 | Phase 2 mobile approval envelope | 2 | Open | #2 | #3, #4 |
| #10 | Product strategy: personas, pricing, and first no-approval action | — | Closed | — | #6, #7 |

## Dependency graph

```
#1 ← #7
#2 ← #1, #7
#9 ← #2
#4 ← #1, #2, #7, #9
#3 ← #9, #2
#6 ← #10
#7 ← #6, #10
```

## Core thesis

Build a trustworthy conductor that keeps track of visible agent sessions
running on the Mac, so a single user can step away, return, and delegate
without re-explaining context. Mobile devices are control surfaces, not
execution hosts. The first win is continuity + control, not raw autonomy.

## Source artifacts

- `README.md` — repository overview and two-layer design
- `AGENTS.md` — local agent instructions and boundaries
- `docs/roadmap.md` — phase entry/exit criteria and success metrics
- `docs/product-strategy.md` — persona, pricing, and first no-approval action
- `docs/architecture/README.md` — architecture notes
- `docs/use-cases/README.md` — use-case catalog
- `docs/decisions/` — architecture decision records
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/voice-visible-session-orchestration-research.md` — technical research synthesis
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/capability-bridge-product-user-perspective.html` — product team and user perspective
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/capability-bridge-v0-architecture.md` — V0 architecture note
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/capability-bridge-advanced-use-cases-roadmap.md` — advanced use-case tracks
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/orchestration-research-brief.html` — readable HTML research brief
- `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/voice-visible-session-orchestration-handoff.md` — original handoff document

## Changelog

- 2026-07-15: Closed #7 and #10; added `docs/roadmap.md` and `docs/product-strategy.md`.
- 2026-07-15: Updated component issue table (#7 and #10 marked Closed).
