/// Session health monitoring for visible agent sessions.

import Foundation

/// Health status of a visible session.
public enum SessionHealthStatus: String, Sendable, Equatable {
    case healthy
    case stale
    case unresponsive
    case stopped
    case unknown
}

/// A snapshot returned by a health check.
public struct SessionHealthSnapshot: Sendable, Equatable {
    public let sessionID: String
    public let status: SessionHealthStatus
    public let checkedAt: Date
    public let reason: String?

    public init(
        sessionID: String,
        status: SessionHealthStatus,
        checkedAt: Date = Date(),
        reason: String? = nil
    ) {
        self.sessionID = sessionID
        self.status = status
        self.checkedAt = checkedAt
        self.reason = reason
    }
}

/// Protocol for health checks that can be run against sessions.
public protocol HealthCheck: Sendable {
    var name: String { get }
    func check(sessionID: String, backend: any PaneBackend) async -> SessionHealthSnapshot
}

/// Health check based on the backend's reported session status.
public struct BackendStatusHealthCheck: HealthCheck {
    public let name = "backend-status"

    public init() {}

    public func check(sessionID: String, backend: any PaneBackend) async -> SessionHealthSnapshot {
        let summaries = await backend.listSessions()
        guard let summary = summaries.first(where: { $0.id == sessionID }) else {
            return SessionHealthSnapshot(
                sessionID: sessionID,
                status: .unknown,
                reason: "Session not found in backend"
            )
        }

        switch summary.status {
        case .running:
            return SessionHealthSnapshot(sessionID: sessionID, status: .healthy)
        case .stopped:
            return SessionHealthSnapshot(sessionID: sessionID, status: .stopped)
        case .unresponsive:
            return SessionHealthSnapshot(
                sessionID: sessionID,
                status: .unresponsive,
                reason: "Backend reported unresponsive"
            )
        case .spawning:
            return SessionHealthSnapshot(sessionID: sessionID, status: .healthy)
        case .paused:
            return SessionHealthSnapshot(sessionID: sessionID, status: .stale)
        case .error:
            return SessionHealthSnapshot(
                sessionID: sessionID,
                status: .unresponsive,
                reason: "Backend reported error"
            )
        }
    }
}

/// Health check that fails if the session has produced no output within a timeout.
public struct OutputStalenessCheck: HealthCheck {
    public let name = "output-staleness"
    public let timeout: TimeInterval

    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    public func check(sessionID: String, backend: any PaneBackend) async -> SessionHealthSnapshot {
        // V0: the bridge does not track per-session last-output timestamps yet,
        // so this check reads output and treats non-empty output as healthy.
        do {
            let output = try await backend.readOutput(sessionID: sessionID)
            if output.isEmpty {
                return SessionHealthSnapshot(
                    sessionID: sessionID,
                    status: .stale,
                    reason: "No output observed within staleness window"
                )
            }
            return SessionHealthSnapshot(sessionID: sessionID, status: .healthy)
        } catch {
            return SessionHealthSnapshot(
                sessionID: sessionID,
                status: .unresponsive,
                reason: "Failed to read output: \(error)"
            )
        }
    }
}

/// Monitors the health of one or more visible sessions.
public actor SessionHealthMonitor {
    private let backend: any PaneBackend
    private let checks: [HealthCheck]
    private var snapshots: [String: SessionHealthSnapshot] = [:]

    public init(backend: any PaneBackend, checks: [HealthCheck]) {
        self.backend = backend
        self.checks = checks
    }

    /// Run all configured health checks against the given session.
    public func check(sessionID: String) async -> [SessionHealthSnapshot] {
        var results: [SessionHealthSnapshot] = []
        for check in checks {
            let snapshot = await check.check(sessionID: sessionID, backend: backend)
            results.append(snapshot)
            snapshots[sessionID] = snapshot
        }
        return results
    }

    /// Aggregate status from the most recent check results.
    public func aggregateStatus(for sessionID: String) async -> SessionHealthStatus {
        let results = await check(sessionID: sessionID)
        if results.contains(where: { $0.status == .unresponsive }) { return .unresponsive }
        if results.contains(where: { $0.status == .stopped }) { return .stopped }
        if results.contains(where: { $0.status == .stale }) { return .stale }
        if results.contains(where: { $0.status == .unknown }) { return .unknown }
        return .healthy
    }

    /// Latest recorded snapshot for a session, if any.
    public func latestSnapshot(for sessionID: String) -> SessionHealthSnapshot? {
        snapshots[sessionID]
    }

    /// All session IDs that have been checked.
    public func monitoredSessions() -> [String] {
        Array(snapshots.keys)
    }
}
