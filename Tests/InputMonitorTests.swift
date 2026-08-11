import Cocoa

final class MockInputMonitorDelegate: InputMonitorDelegate {
    var triggerCount = 0
    var lastCapturedText: String?

    func triggerTranslation(for text: String, completion: @escaping (String?) -> Void) {
        triggerCount += 1
        lastCapturedText = text
        completion("Translated: \(text)")
    }
}

// The hotkey registration and capture macro need real Accessibility/Input
// Monitoring permissions and a focused target app, so only the pure logic is
// tested here. The full flow is verified manually via the built .app.
func runInputMonitorTests() {
    test("monitor starts enabled with its delegate set") {
        let monitor = InputMonitor()
        let delegate = MockInputMonitorDelegate()
        monitor.delegate = delegate
        expect(monitor.isEnabled, "monitor should default to enabled")
        expectNotNil(monitor.delegate)
    }

    test("disabled monitor ignores hotkey") {
        let monitor = InputMonitor()
        let delegate = MockInputMonitorDelegate()
        monitor.delegate = delegate
        monitor.isEnabled = false

        monitor.handleHotKey()

        // The enabled path dispatches async to main; spin briefly to prove
        // nothing was scheduled.
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        expectEqual(delegate.triggerCount, 0, "delegate must not fire while disabled")
    }
}
