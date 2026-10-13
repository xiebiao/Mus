// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mus",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Mus", targets: ["Mus"])],
    targets: [
        .target(name: "MouseCore"),
        .executableTarget(name: "Mus", dependencies: ["MouseCore"],
                          resources: [.process("Resources")]),
        .testTarget(name: "MouseCoreTests", dependencies: ["MouseCore"]),
        .testTarget(name: "MusTests", dependencies: ["Mus"])
    ]
)
