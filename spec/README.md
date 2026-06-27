# Capability Bridge contracts

Language-agnostic schema definitions for bridge primitives.

These schemas exist so non-Swift agents and runtimes can participate in the bridge without reverse-engineering Swift source. The Swift implementation in `Sources/CapabilityBridge` is the reference implementation.

## Contracts

### COG → SDL

- `cog-intent.schema.json` — user intent with locale, confidence, transcription
- `task-frame.schema.json` — canonical task envelope (CogTaskFrame)
- `context-bundle.schema.json` — bounded workspace context (CogContext)
- `approval-response.schema.json` — user's approve/deny/defer response
- `trace-event.schema.json` — append-only correlation record (CogTraceEvent)
- `cog-pane-backend-event.schema.json` — pane lifecycle event

### SDL → COG

- `capability-packet.schema.json` — task routed to SDL capability
- `capability-plan.schema.json` — planned steps, risk, approvals
- `approval-request.schema.json` — human decision envelope
- `artifact-summary.schema.json` — compact result artifact

### Shared

- `cog-target-resolution.schema.json` — target query and resolution
- `cog-bridge-error.schema.json` — shared error envelope

## Design note

Schemas are derived from the canonical `workspace-types` Swift contract (`cog_bridge_contract/`) at version `0.2.0`. These JSON Schema files exist so non-Swift agents and runtimes can participate without compiling Swift. The Swift types in `workspace-types` are the single source of truth.
