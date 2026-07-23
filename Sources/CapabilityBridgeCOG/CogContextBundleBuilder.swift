import Foundation
import WorkspaceTypes

/// A bounded, bridge-internal context bundle derived from `CogContext`.
///
/// `ContextBundle` is intentionally smaller than `CogContext`. It carries only
/// the references and metadata SDL needs for planning and approval, without
/// exposing raw workspace state.
package struct ContextBundle: Sendable, Equatable {
    package var workspaceSnapshot: String
    package var noteRefs: [String]
    package var memorySnippets: [String]
    package var artifactRefs: [String]
    package var aurRefs: [String]
    package var omissions: [String]
    package var freshness: Date
    package var tokenBudget: Int
    package var rawContentPolicy: String

    package init(
        workspaceSnapshot: String,
        noteRefs: [String] = [],
        memorySnippets: [String] = [],
        artifactRefs: [String] = [],
        aurRefs: [String] = [],
        omissions: [String] = [],
        freshness: Date,
        tokenBudget: Int = 4096,
        rawContentPolicy: String = "redact-sensitive"
    ) {
        self.workspaceSnapshot = workspaceSnapshot
        self.noteRefs = noteRefs
        self.memorySnippets = memorySnippets
        self.artifactRefs = artifactRefs
        self.aurRefs = aurRefs
        self.omissions = omissions
        self.freshness = freshness
        self.tokenBudget = tokenBudget
        self.rawContentPolicy = rawContentPolicy
    }
}

/// Builds a `ContextBundle` from a `CogContext`.
package struct CogContextBundleBuilder: Sendable {

    package init() {}

    package func build(from context: CogContext) -> ContextBundle {
        ContextBundle(
            workspaceSnapshot: workspaceSnapshot(from: context),
            noteRefs: context.noteRefs,
            memorySnippets: [],
            artifactRefs: [],
            aurRefs: [],
            omissions: omissions(for: context),
            freshness: Date(timeIntervalSince1970: Double(context.timestamp) / 1000.0),
            tokenBudget: context.tokenBudget,
            rawContentPolicy: context.rawContentPolicy
        )
    }

    // MARK: - Helpers

    private func workspaceSnapshot(from context: CogContext) -> String {
        let activeTab = context.activeTabID ?? "none"
        let activeSurface = context.activeSurfaceID ?? "none"
        return [
            "device=\(context.activeDeviceID)",
            "transport=\(context.transportPath.rawValue)",
            "tabs=\(context.tabs.count)",
            "surfaces=\(context.surfaces.count)",
            "hosts=\(context.hosts.count)",
            "activeTab=\(activeTab)",
            "activeSurface=\(activeSurface)",
        ].joined(separator: "; ")
    }

    private func omissions(for context: CogContext) -> [String] {
        switch context.rawContentPolicy {
        case "include":
            return []
        default:
            return ["raw_output"]
        }
    }
}
