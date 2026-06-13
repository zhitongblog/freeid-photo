// swift-tools-version: 6.0
import PackageDescription

// FreeID Photo — free, on-device, global ID-photo app.
//
//   FreeIDCore (pure logic, no UI)  ──┬── FreeIDApp (SwiftUI, separate Xcode project)
//                                     ├── freeidctl (CLI driver, self-test + scripting)
//                                     └── freeid-mcp (MCP server — added later)
//
// FreeIDCore is deliberately UI-free so the App, the CLI, and the MCP server all
// share one validated core. Spec validation is decoupled from Vision so it is
// 100% unit-testable with synthetic FaceMetrics (no camera, no device).

let package = Package(
    name: "FreeIDPhoto",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "FreeIDCore", targets: ["FreeIDCore"]),
        .executable(name: "freeidctl", targets: ["freeidctl"]),
        .executable(name: "freeid-mcp", targets: ["freeid-mcp"]),
    ],
    targets: [
        .target(
            name: "FreeIDCore",
            resources: [.copy("Specs")]
        ),
        .executableTarget(
            name: "freeidctl",
            dependencies: ["FreeIDCore"]
        ),
        .executableTarget(
            name: "freeid-mcp",
            dependencies: ["FreeIDCore"]
        ),
        .testTarget(
            name: "FreeIDCoreTests",
            dependencies: ["FreeIDCore"]
        ),
    ]
)
