// swift-tools-version: 6.2
import PackageDescription

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
        .package(url: "https://github.com/cocogiri/workspace-types.git", branch: "main")
    ],
    targets: [
        .target(name: "CapabilityBridge", dependencies: [.product(name: "WorkspaceTypes", package: "workspace-types")]),
        .target(name: "CapabilityBridgeCOG", dependencies: ["CapabilityBridge", "CapabilityBridgeSDL", "ApprovalSurfaces", .product(name: "WorkspaceTypes", package: "workspace-types")]),
        .target(name: "CapabilityBridgeSDL", dependencies: ["CapabilityBridge", .product(name: "WorkspaceTypes", package: "workspace-types")]),
        .target(name: "PaneBackends", dependencies: ["CapabilityBridge", .product(name: "WorkspaceTypes", package: "workspace-types")]),
        .target(name: "ApprovalSurfaces", dependencies: ["CapabilityBridge", .product(name: "WorkspaceTypes", package: "workspace-types")]),
        .target(name: "ModelRouting", dependencies: ["CapabilityBridge", .product(name: "WorkspaceTypes", package: "workspace-types")]),
        .testTarget(name: "CapabilityBridgeTests", dependencies: ["CapabilityBridge", "CapabilityBridgeCOG", "CapabilityBridgeSDL", "PaneBackends", "ApprovalSurfaces", .product(name: "WorkspaceTypes", package: "workspace-types")]),
    ]
)
