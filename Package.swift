// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HingeVeil",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HingeVeil", targets: ["HingeVeil"]),
               .executable(name: "HingeVeilRecovery", targets: ["HingeVeilRecovery"])],
    targets: [
        .target(name: "HingeVeilCore", resources: [.process("Resources")]),
        .executableTarget(name: "HingeVeil", dependencies: ["HingeVeilCore"],
                          resources: [.copy("Resources/Veil.metal"), .copy("Resources/PreviewTiger.png")]),
        .executableTarget(name: "HingeVeilRecovery", dependencies: ["HingeVeilCore"]),
        .testTarget(name: "HingeVeilCoreTests", dependencies: ["HingeVeilCore"])
    ]
)
