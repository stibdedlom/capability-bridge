# Decision 004: COG owns surfaces and transport; Bridge owns protocol translation and SDL orchestration

## Status

Accepted.

## Context

Capability Bridge issue #3 defined a broad cross-device control surface model.
Issue #9 defined a Phase 2 mobile approval envelope with device pairing,
transport, mobile UI, biometric gates, command queueing, and bridge approval
contracts in one place.

That scope overlaps with COG workspace work:

- `cocogiri/workspace-core#5` owns cross-surface session orchestration.
- `cocogiri/workspace-core#20` owns CloudKit command/output transport.
- `cocogiri/workspace-core#21` owns the iOS session list and terminal UI.
- `cocogiri/workspace-core#26` owns direct local device transport.

The bridge still needs approval, trace, and routing contracts, but it must not
grow a parallel COG surface layer or mobile transport stack.

## Decision

COG owns human-facing workspace surfaces and transport:

- device-specific UI on Mac, iPhone, iPad, Apple Watch, tvOS, and Vision Pro;
- surface rituals such as biometric gates, hold-to-confirm controls, and local
  confirmation affordances;
- CloudKit, direct local, and future workspace transport;
- device pairing, offline command queues, delivery acknowledgements, and
  surface-level retries;
- presentation of bridge-produced plans, approval requests, traces, and
  artifact summaries.

The Capability Bridge owns protocol translation and SDL orchestration:

- `Intent` to `TaskFrame` translation;
- `ContextBundle` assembly and provenance boundaries;
- `CapabilityPacket` shaping for SDL routing and lifecycle;
- `ApprovalRequest` and `ApprovalResponse` contracts;
- trace event emission for bridge decisions and approval resolution;
- bridge-side interpretation of COG approval responses;
- coordination with SDL lifecycle, routing, memory, telemetry, and governed
  execution capabilities.

The bridge may provide adapters for COG and SDL, but those adapters translate
contracts. They do not own COG surfaces, mobile transport, or device UI.

## Consequences

- Cross-device surface design lives in COG, not in this repository.
- Bridge issues that specify device roles, transport behavior, mobile UI, or
  biometric rituals must be moved to COG or closed as out of bridge scope.
- Bridge issues may retain the protocol envelope: request fields, response
  fields, trace correlation, risk tier semantics, expiry, idempotency, and SDL
  lifecycle linkage.
- Decision 003 remains valid only for bridge-owned `PaneBackend` protocol and
  SDL-visible session orchestration. It does not grant ownership of COG device
  surfaces or workspace transport.
- Future bridge work must reference this decision when a feature crosses COG
  surface/transport boundaries.
