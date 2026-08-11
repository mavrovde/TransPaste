// swift-tools-version: 5.9
import PackageDescription

// Tests are not an SPM testTarget: they use a self-contained harness
// (Tests/TestKit.swift) instead of XCTest, so they run on machines with only
// Command Line Tools installed. Run them with ./test.sh.
let package = Package(
    name: "TransPaste",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TransPaste", targets: ["TransPaste"])
    ],
    targets: [
        .executableTarget(
            name: "TransPaste",
            path: "Sources"
        )
    ]
)
