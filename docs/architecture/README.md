# Architecture decisions

This directory records architecture decisions for the Capability Bridge.

## Active decisions

- **Two-layer design.** Language-agnostic contracts in `spec/` plus Swift reference implementation in `Sources/`. This lets future non-Swift runtimes participate without reimplementing the contract from Swift source.
- **Protocol-oriented, not framework-oriented.** The bridge exposes protocols for pane backends, approval surfaces, model routers, and worker executors. Concrete implementations are supplements, not hardcoded dependencies.
- **Mac execution hub, mobile control surfaces.** iPhone, iPad, Watch, tvOS, and Vision Pro send structured commands to Mac-running sessions. They do not execute agents locally.
- **Traceability from day one.** Every decision emits a `TraceEvent` so the system remains auditable and resumable.

## Tensions preserved

- Autonomy vs. control: bounded loops with absolute stop conditions.
- Visibility vs. cognitive load: Conductor collapses inactive sessions.
- Voice vs. screen: voice initiates/interrupts/approves; complex state lives on screen.
- Mobile vs. Mac: mobile approves; Mac executes.
