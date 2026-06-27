// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "capability-bridge",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "CapabilityBridge", targets: ["CapabilityBridge"]),
        .library(name: "CapabilityBridgeCOG", targets: ["CapabilityBridgeCOG"]),
        .library(name: "CapabilityBridgeSDL", targets: ["CapabilityBridgeSDL"]),
        .library(name: "PaneBackends", targets: ["PaneBackends"]),
        .library(name: "ApprovalSurfaces", targets: ["ApprovalSurfaces"]),
        .library(name: "ModelRouting", targets: ["ModelRouting"]),
        .executable(name: "WorkerReviewerExample", targets: ["WorkerReviewerExample"]),
    ],
    targets: [
        .target(name: "CapabilityBridge"),
        .target(name: "CapabilityBridgeCOG", dependencies: ["CapabilityBridge"]),
        .target(name: "CapabilityBridgeSDL", dependencies: ["CapabilityBridge"]),
        .target(name: "PaneBackends", dependencies: ["CapabilityBridge"]),
        .target(name: "ApprovalSurfaces", dependencies: ["CapabilityBridge"]),
        .target(name: "ModelRouting", dependencies: ["CapabilityBridge"]),
        .executableTarget(
            name: "WorkerReviewerExample",
            dependencies: ["CapabilityBridge", "PaneBackends"],
            path: "examples/worker-reviewer-pair",
            exclude: ["README.md"]
        ),
        .testTarget(name: "CapabilityBridgeTests", dependencies: ["CapabilityBridge", "PaneBackends"]),
    ]
)
