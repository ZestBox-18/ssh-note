// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "SSHNote", platforms: [.macOS(.v15)], products: [.executable(name: "SSHNote", targets: ["SSHNote"])], targets: [.target(name: "SSHNoteCore"), .executableTarget(name: "SSHNote", dependencies: ["SSHNoteCore"]), .executableTarget(name: "CoreChecks", dependencies: ["SSHNoteCore"], path: "Tests/SSHNoteCoreTests")])
