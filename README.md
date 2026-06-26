# capability-bridge

A protocol-oriented translation layer between COG workspace surfaces and SDL governed capabilities.

## What it is

The Capability Bridge turns messy human intent from COG into structured, governed, traceable agent work through SDL. It does not replace COG, SDL, or AUR. It sits between them and owns:

- `Intent` → `TaskFrame` intake
- Bounded `ContextBundle` assembly
- `CapabilityPacket` shaping for SDL
- Compact `CapabilityPlan` or read-only results back to COG
- `ApprovalRequest` envelopes and confirmation rituals
- `TraceEvent` emission for every decision
- `ArtifactSummary` packaging for user display
- `PaneBackend` abstraction for visible agent sessions

## Two-layer design

```
┌─────────────────────────────────────────┐
│  Layer 1: Language-agnostic contracts   │
│  JSON Schema / OpenAPI / protobuf specs │
│  for frames, packets, approvals, traces │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│  Layer 2: Swift reference implementation│
│  Protocols, adapters, pane backends,    │
│  approval surfaces, model routers       │
└─────────────────────────────────────────┘
```

The spec layer is thin and derived from implementation needs. It exists so future non-Swift agents and runtimes can participate without reverse-engineering Swift source.

## What it is not

- A chatbot.
- A replacement for SDL governance.
- A replacement for COG workspace UX.
- A replacement for AUR research and source grounding.
- A hardcoded dependency on any single agent runtime, terminal multiplexer, or model provider.

## Repository layout

```
.
├── AGENTS.md
├── README.md
├── Package.swift
├── spec/
│   ├── task-frame.schema.json
│   ├── context-bundle.schema.json
│   ├── capability-packet.schema.json
│   ├── approval-request.schema.json
│   ├── trace-event.schema.json
│   └── artifact-summary.schema.json
├── Sources/
│   ├── CapabilityBridge/          # Core protocols and orchestration
│   ├── CapabilityBridgeCOG/       # COG signal adapters
│   ├── CapabilityBridgeSDL/       # SDL routing/lifecycle adapters
│   ├── PaneBackends/              # tmux, Zellij, native window adapters
│   ├── ApprovalSurfaces/          # iOS, watchOS, macOS surfaces
│   └── ModelRouting/              # On-device, cloud, local model adapters
├── Tests/
├── docs/
│   ├── architecture/
│   ├── use-cases/
│   └── decisions/
└── examples/
    └── worker-reviewer-pair/      # First prototype reference
```

## V0 scope

V0 is **observe/advise only**. It may summarize, route, propose, and request approval. It does not perform client-repo mutation, branch management, memory promotion, provider dispatch, or autonomous self-improvement.

## Apple-first baseline

- macOS 26 latest stable
- Apple Silicon Mac, M1 or later
- 16 GB unified memory minimum
- Apple Intelligence available when used
- App Intents, Shortcuts, Speech, AVSpeechSynthesizer, Core ML, MLX, Service Management, and TCC-aware permissions behind adapters

## Related work

- `projects/stibdedlom-ideation-workshop/voice-visible-session-orchestration-research.md`
- `projects/stibdedlom-ideation-workshop/capability-bridge-product-user-perspective.html`
- `projects/stibdedlom-ideation-workshop/capability-bridge-v0-architecture.md`
- `stibdedlom/infra`

## Status

Research complete. Repository seeded. Issues and first prototype work tracked in GitHub Issues.
