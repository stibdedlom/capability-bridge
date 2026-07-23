# Capability Bridge contracts

Language-agnostic schema definitions for bridge primitives.

These schemas exist so non-Swift agents and runtimes can participate in the bridge without reverse-engineering Swift source. The Swift implementation in `Sources/CapabilityBridge` is the reference implementation.

## Contracts

### Core bridge contracts

- `task-frame.schema.json` — intake artifact for a unit of work
- `capability-plan.schema.json` — routing plan with primary route, fallbacks, confidence, and authority
- `context-bundle.schema.json` — bounded context package with provenance
- `capability-packet.schema.json` — request from bridge to SDL capability layer
- `approval-request.schema.json` — human decision envelope for risky actions
- `trace-event.schema.json` — append-only correlation record
- `artifact-summary.schema.json` — compact result for user display

### COG → SDL

- `cog-intent.schema.json` — user intent with locale, confidence, transcription
- `approval-response.schema.json` — user's approve/deny/defer response
- `cog-pane-backend-event.schema.json` — pane lifecycle event

### Shared

- `cog-target-resolution.schema.json` — target query and resolution
- `cog-bridge-error.schema.json` — shared error envelope

## Design note

Schemas are intentionally minimal for V0. They will evolve as the Swift reference implementation discovers real constraints.
