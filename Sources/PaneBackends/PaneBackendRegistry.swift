/// Registry for selecting and dispatching to pane backends.

import CapabilityBridge
import Foundation

/// Selects a concrete `PaneBackend` by role hint or explicit backend id.
///
/// The registry is intentionally small: it maps roles (e.g., "worker", "reviewer")
/// to backends without owning session lifecycle logic.
public actor PaneBackendRegistry {
    private var backends: [String: any PaneBackend] = [:]
    private var roleMappings: [String: String] = [:]

    public init() {}

    /// Register a backend under its own `backendID`.
    public func register(_ backend: any PaneBackend) async {
        backends[backend.backendID] = backend
    }

    /// Map a role to a backend id.
    public func mapRole(_ role: String, toBackend backendID: String) async {
        roleMappings[role] = backendID
    }

    /// Resolve a backend for the given role.
    public func backend(forRole role: String) async throws -> any PaneBackend {
        guard let backendID = roleMappings[role] else {
            throw PaneBackendError.backendUnavailable
        }
        guard let backend = backends[backendID] else {
            throw PaneBackendError.backendUnavailable
        }
        return backend
    }

    /// Resolve a backend by explicit id.
    public func backend(id: String) async throws -> any PaneBackend {
        guard let backend = backends[id] else {
            throw PaneBackendError.backendUnavailable
        }
        return backend
    }

    /// All registered backend summaries.
    public func registeredBackendIDs() async -> [String] {
        Array(backends.keys)
    }
}
