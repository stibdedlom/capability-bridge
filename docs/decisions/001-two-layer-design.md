# Decision 001: Two-layer design (language-agnostic spec + Swift implementation)

## Status

Accepted.

## Context

The Capability Bridge must work with multiple agent runtimes over time. Some runtimes may be Swift-native (COG, SDL), while others may be Python, Rust, or shell-based agents. A single-language implementation would force every future participant to read Swift source to understand the contract.

## Decision

Maintain two layers:

1. **Language-agnostic contracts** in `spec/` (JSON Schema / OpenAPI / protobuf) for `TaskFrame`, `ContextBundle`, `CapabilityPacket`, `ApprovalRequest`, `TraceEvent`, and `ArtifactSummary`.
2. **Swift reference implementation** in `Sources/CapabilityBridge` that realizes those contracts and provides protocols for adapters.

The spec layer is thin and evolves alongside the Swift implementation. We do not spec-first; we implement, then extract the contract.

## Consequences

- Future non-Swift agents can participate without reimplementing from Swift source.
- We avoid over-engineering by deriving schemas from working code.
- We accept the maintenance cost of keeping spec and code in sync.
