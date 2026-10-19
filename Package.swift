// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HingeVeil",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HingeVeil", targets: ["HingeVeil"])],
    targets: [
        .target(name: "HingeVeilCore", resources: [.process("Resources")]),
        .executableTarget(name: "HingeVeil", dependencies: ["HingeVeilCore"],
                          resources: [.copy("Resources/Veil.metal"), .copy("Resources/PreviewTiger.png")]),
        .testTarget(name: "HingeVeilCoreTests", dependencies: ["HingeVeilCore"])
    ]
)
