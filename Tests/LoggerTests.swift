import Foundation

func runLoggerTests() {
    test("Logger is a singleton") {
        expect(Logger.shared === Logger.shared)
    }

    test("log appends message to the log file") {
        let marker = "Test Log Entry \(UUID().uuidString)"
        Logger.shared.log(marker)
        Logger.shared.flush()

        let content = (try? String(contentsOf: Logger.shared.logURL, encoding: .utf8)) ?? ""
        expect(content.contains(marker), "log file should contain the logged message")
    }

    test("concurrent logging loses no messages") {
        let marker = UUID().uuidString
        let iterations = 50
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            Logger.shared.log("Concurrent \(marker) #\(i)")
        }
        Logger.shared.flush()

        let content = (try? String(contentsOf: Logger.shared.logURL, encoding: .utf8)) ?? ""
        for i in 0..<iterations {
            if !content.contains("Concurrent \(marker) #\(i)") {
                failTest("missing concurrent log entry #\(i)")
                break
            }
        }
    }
}
