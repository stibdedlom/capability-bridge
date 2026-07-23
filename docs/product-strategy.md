# Capability Bridge Product Strategy

This document collects the product-strategy decisions for the Capability
Bridge. It satisfies
[capability-bridge#10](https://github.com/stibdedlom/capability-bridge/issues/10).

## Primary persona

**Solo developer consultant**

A single developer who switches between 5–10 client projects per quarter and
loses context every time they resume a project. They already use Claude Code,
terminal AI, or tmux scripts but struggle to keep session state, approvals,
and traces coherent across interruptions.

### Evidence

- Research synthesis in `v-i-s-h-a-l/explorations/projects/stibdedlom-ideation-workshop/capability-bridge-product-user-perspective.html`
  identifies continuity and control as the top pain points.
- The Capability Bridge two-layer design and visible-session pair target exactly
  the resume-and-delegate workflow.

## Fallback persona

**Small agency team lead**

A technical lead who delegates review-heavy tasks to junior contractors. They
need an audit trail of every agent action and a fast way to stop or redirect
work from a mobile device.

## Pricing hypothesis

**Per active project per month**, with a free tier for one project.

### Rationale

- Seat-based pricing under-values sporadic, high-value usage.
- Session-hour pricing discourages the long-running background sessions that
  provide the most continuity value.
- Per-successful-task completion is hard to define and easy to game.
- Per-project pricing aligns with the continuity promise and is simple to
  explain.

### Decision date

Revisit after Phase 2 prototype is evaluated with 5–10 target users.

## Replaced tool

The first tool users replace is **manual context copy-paste** between terminal
sessions, chat threads, and project notes.

### Evidence

- Research notes describe the current workflow as "re-explaining context after
  every interruption."
- Adjacent tools (Claude Code Agent Teams, OpenHands) solve collaboration but
  still assume the user is present at the keyboard.
- The Capability Bridge differentiator is persistent, visible, interruptible
  sessions plus mobile control.

## First no-approval action

**Read-only file inspection and trace emission.**

### Safety boundary

The bridge may read files, build a `ContextBundle`, and emit `TraceEvent`s
without explicit approval, provided:

1. The action is classified as `observe` or `advise` in the V0 taxonomy.
2. No file mutation, branch creation, network call, or command execution occurs.
3. The action is scoped to the current `TaskFrame`.
4. A `TraceEvent` is emitted linking the action to the `TaskFrame` and parent
   trace.

Any action outside this boundary requires an `ApprovalRequest` and a matching
`ApprovalResponse` before the Worker proceeds.

## Open questions tracker

| Question | Status | Owner | Next action |
|---|---|---|---|
| Persona validation | provisional | product | 5–10 user interviews after Phase 2 |
| Pricing model | provisional | product | Revisit after Phase 2 evaluation |
| Replaced-tool claim | provisional | research | Add user quotes to this doc |
| No-approval boundary | decided | engineering | Enforce in V0 taxonomy and tests |

## Links

- [capability-bridge#6](https://github.com/stibdedlom/capability-bridge/issues/6) — Open questions and risks
- [capability-bridge#7](https://github.com/stibdedlom/capability-bridge/issues/7) — Roadmap and success metrics
- `docs/use-cases/README.md`
