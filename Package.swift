// swift-tools-version: 6.2
import PackageDescription

// PR-prep: switch the WorkspaceTypes dependency to a git URL before opening the PR:
// `.package(url: "https://github.com/cocogiri/workspace-types.git", branch: "feature/cog-bridge-contract-alignment")`
let workspaceTypesPath = "../../cocogiri/workspace-types-worktree-cog-bridge-1"

let package = Package(
    name: "capability-bridge",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "CapabilityBridge", targets: ["CapabilityBridge"]),
        .library(name: "CapabilityBridgeCOG", targets: ["CapabilityBridgeCOG"]),
        .library(name: "CapabilityBridgeSDL", targets: ["CapabilityBridgeSDL"]),
        .library(name: "PaneBackends", targets: ["PaneBackends"]),
        .library(name: "ApprovalSurfaces", targets: ["ApprovalSurfaces"]),
        .library(name: "ModelRouting", targets: ["ModelRouting"]),
    ],
    dependencies: [
        .package(name: "WorkspaceTypes", path: workspaceTypesPath)
    ],
    targets: [
        .target(name: "CapabilityBridge", dependencies: ["WorkspaceTypes"]),
        .target(name: "CapabilityBridgeCOG", dependencies: ["CapabilityBridge", "WorkspaceTypes"]),
        .target(name: "CapabilityBridgeSDL", dependencies: ["CapabilityBridge", "WorkspaceTypes"]),
        .target(name: "PaneBackends", dependencies: ["CapabilityBridge", "WorkspaceTypes"]),
        .target(name: "ApprovalSurfaces", dependencies: ["CapabilityBridge", "WorkspaceTypes"]),
        .target(name: "ModelRouting", dependencies: ["CapabilityBridge", "WorkspaceTypes"]),
        .testTarget(name: "CapabilityBridgeTests", dependencies: ["CapabilityBridge", "CapabilityBridgeCOG", "CapabilityBridgeSDL", "PaneBackends", "WorkspaceTypes"]),
    ]
)
