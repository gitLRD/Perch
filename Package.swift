// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "Perch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Perch", path: "Sources/Perch"),
        .testTarget(name: "PerchTests", dependencies: ["Perch"], path: "Tests/PerchTests",
                    resources: [.copy("Fixtures")])
    ]
)
