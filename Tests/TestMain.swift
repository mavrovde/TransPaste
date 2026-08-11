import Foundation

@main
struct TestMain {
    static func main() {
        if let filter = TestKit.filter {
            print("Running tests matching \"\(filter)\"\n")
        }
        runGoogleGeminiServiceTests()
        runInputMonitorTests()
        runLoggerTests()
        TestKit.summaryAndExit()
    }
}
