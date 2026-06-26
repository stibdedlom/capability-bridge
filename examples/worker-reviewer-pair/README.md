# Example: Worker + Reviewer visible session pair

This example demonstrates the first Capability Bridge prototype.

## Flow

1. User creates a `TaskFrame` in COG via text or voice.
2. Bridge asks SDL for routing; SDL selects Worker and Reviewer capabilities.
3. Bridge spawns two visible sessions: Worker and Reviewer in separate panes/windows.
4. Worker proceeds in a bounded loop: plan → execute → verify → checkpoint.
5. Reviewer critiques at checkpoints and can force a stop or request human review.
6. At a checkpoint or risky action, the bridge sends an `ApprovalRequest` to iPhone/Watch.
7. User approves, edits scope, redirects, or stops; the bridge updates state and emits `TraceEvent`s.

## Why this example

- Exercises intent framing, visible sessions, roles, inbox/outbox, stop conditions, mobile approval, and trace emission together.
- Does not require full autonomous mutation, cross-project orchestration, or spatial computing.
- Produces trust before autonomy.
- Can run against a safe target such as a docs repo or test suite before touching client code.
