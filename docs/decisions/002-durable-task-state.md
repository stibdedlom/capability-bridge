# Decision 002: Durable task state lives in SDL lifecycle records and traces

## Status

Accepted.

## Context

The bridge needs to know the current state of a `TaskFrame` and its sessions. The open question is whether the bridge owns durable storage or delegates it.

## Decision

The Capability Bridge does **not** own durable task state. Durable state lives in:

- SDL lifecycle records (source of truth for governance and lifecycle).
- Trace events (append-only audit and resumption log).

The bridge owns the in-memory representation (`TaskFrame`, session tree) and the logic to hydrate/dehydrate from SDL records and traces.

## Consequences

- SDL remains the single source of truth for governance.
- The bridge can be restarted or replaced without losing state.
- All bridge actions remain auditable through SDL traces.
