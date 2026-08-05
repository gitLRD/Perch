// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "Perch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PerchCore",
            path: "Sources/PerchCore",
            swiftSettings: [.unsafeFlags(["-enable-testing"], .when(configuration: .debug))]
        ),
        .executableTarget(name: "Perch", dependencies: ["PerchCore"], path: "Sources/Perch"),
        .executableTarget(
            name: "PerchTestRunner",
            dependencies: ["PerchCore"],
            path: "Tests/PerchTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
