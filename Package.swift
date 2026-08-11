// swift-tools-version: 6.0
import PackageDescription

// Tests are not an SPM testTarget: they use a self-contained harness
// (Tests/TestKit.swift) instead of XCTest, so they run on machines with only
// Command Line Tools installed. Run them with ./test.sh.
//
// Language mode is pinned to v5: the AppKit/Carbon code predates strict
// concurrency, and migrating it is tracked separately from toolchain bumps.
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
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
