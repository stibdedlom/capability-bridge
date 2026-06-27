import Foundation
import WorkspaceTypes

/// Capability Bridge core orchestration types.
///
/// This module consumes the cross-boundary contracts defined in
/// `WorkspaceTypes` and provides task-lifecycle state that is private to the
/// bridge. Concrete adapters for COG, SDL, pane backends, approval surfaces,
/// and model routers live in separate targets so they can be replaced without
/// changing the core.
///
/// `CapabilityBridge` is intentionally thin: it does not import UI frameworks
/// or `WorkspaceCore`, and it performs no SDL capability execution.
