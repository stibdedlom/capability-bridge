# Decision 003: The bridge owns visible session orchestration, not COG

## Status

Accepted.

## Context

COG is the human workspace surface. The temptation is to let COG manage terminal panes and windows because it owns the UI. However, session orchestration is a bridge concern: it must be governed, typed, traceable, and independent of any single UI.

## Decision

The Capability Bridge owns the `PaneBackend` protocol and the orchestration of visible sessions. COG provides the human surface and renders bridge-managed sessions. COG does not create, stop, or route sessions on its own.

## Consequences

- The bridge can manage sessions across tmux, Zellij, native windows, or future backends without COG changes.
- COG remains a thin, replaceable human interface.
- All pane lifecycle events flow through bridge trace events.
