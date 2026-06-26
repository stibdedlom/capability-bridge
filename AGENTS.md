> Local agent instructions for the capability-bridge repository.

## Repository purpose

This repository implements the Capability Bridge: a protocol-oriented translation layer between COG workspace surfaces and SDL governed capabilities.

## Relationship to other repositories

- **COG / Cocogiri**: owns the human workspace surface. The bridge consumes COG `Intent` signals and returns compact plans or results.
- **SDL / stibdedlom**: owns governance, capability registry, routing, lifecycle, memory, telemetry, and self-improvement. The bridge asks SDL for routing decisions and emits traces into SDL lifecycle records.
- **AUR / Aura Knowledge**: owns research, source grounding, references, and synthesis. The bridge may include AUR refs in `ContextBundle`s but does not own AUR logic.
- **Explorations vault**: `v-i-s-h-a-l/explorations` contains the original research notes, HTML briefs, and handoff artifacts. This repo implements the architecture those artifacts describe.

## Design principles

1. **Protocol first, implementation second.** Contracts are defined in `spec/` as language-agnostic schemas. Swift implementation follows the contract.
2. **No hardcoded agent runtime.** Claude Code, OpenHands, Codex, and custom agents are plugged in as worker executors.
3. **No hardcoded multiplexer.** tmux, Zellij, native windows, and future terminal APIs are plugged in through `PaneBackend`.
4. **No hardcoded model provider.** Apple Foundation Models, MLX, Private Cloud Compute, and remote providers are plugged in through the model router.
5. **Traceability before behavior expansion.** Every decision emits a `TraceEvent`.
6. **Mobile devices are control surfaces, not execution hosts.** The Mac remains the execution hub.

## Build and test

TBD. Initial structure uses Swift Package Manager.

## Skill routing

When a user invokes `$stibdedlom` or `use stibdedlom`, follow the global stibdedlom skill routing and load `capability-routing` from `stibdedlom/infra`.

## Forbidden patterns

- Do not call SDL capabilities directly from COG; route through the bridge.
- Do not hardcode Apple APIs inside core bridge contracts; keep them behind adapters.
- Do not emit headless agent actions without trace events and approval gates when trust matters.
- Do not promote memory without explicit source, scope, confidence, privacy class, retention, expiry, and approval.
