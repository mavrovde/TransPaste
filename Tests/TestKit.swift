import Foundation

// Minimal test harness. XCTest is not available with Command Line Tools-only
// installs (this project builds with swiftc, no Xcode), so tests run as a plain
// executable: `./test.sh [name-filter]`.

enum TestKit {
    static var totalRun = 0
    static var totalSkipped = 0
    static var failedTests: [String] = []
    static var currentFailures: [String] = []

    static var filter: String? {
        let args = CommandLine.arguments.dropFirst()
        return args.first
    }

    static func summaryAndExit() -> Never {
        print("")
        if totalSkipped > 0 {
            print("Skipped: \(totalSkipped)")
        }
        if failedTests.isEmpty {
            print("PASSED: all \(totalRun) tests")
            exit(0)
        } else {
            print("FAILED: \(failedTests.count) of \(totalRun) tests")
            failedTests.forEach { print("  - \($0)") }
            exit(1)
        }
    }
}

func test(_ name: String, _ body: () throws -> Void) {
    if let filter = TestKit.filter, !name.localizedCaseInsensitiveContains(filter) {
        return
    }
    TestKit.totalRun += 1
    TestKit.currentFailures = []
    do {
        try body()
    } catch {
        TestKit.currentFailures.append("unexpected error: \(error)")
    }
    if TestKit.currentFailures.isEmpty {
        print("ok      \(name)")
    } else {
        TestKit.failedTests.append(name)
        print("FAIL    \(name)")
        TestKit.currentFailures.forEach { print("        \($0)") }
    }
}

func skip(_ name: String, reason: String) {
    TestKit.totalSkipped += 1
    print("skip    \(name) (\(reason))")
}

func expect(_ condition: Bool, _ message: String = "expected true", line: Int = #line) {
    if !condition {
        TestKit.currentFailures.append("\(message) [line \(line)]")
    }
}

func expectEqual<T: Equatable>(_ actual: T?, _ expected: T?, _ message: String = "", line: Int = #line) {
    if actual != expected {
        let detail = message.isEmpty ? "" : "\(message): "
        TestKit.currentFailures.append(
            "\(detail)expected \(String(describing: expected)), got \(String(describing: actual)) [line \(line)]")
    }
}

func expectNotNil<T>(_ value: T?, _ message: String = "expected non-nil", line: Int = #line) {
    if value == nil {
        TestKit.currentFailures.append("\(message) [line \(line)]")
    }
}

func failTest(_ message: String, line: Int = #line) {
    TestKit.currentFailures.append("\(message) [line \(line)]")
}

// Spins the main run loop until the condition holds. Safe for completions that
// hop to the main queue (a semaphore wait here would deadlock).
func waitUntil(_ description: String, timeout: TimeInterval = 3, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    if !condition() {
        TestKit.currentFailures.append("timed out waiting for \(description)")
    }
}
