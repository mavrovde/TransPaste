import Foundation

@main
struct TestMain {
    static func main() {
        // Hermetic provider config: never read or create ~/.transpaste from tests
        ProviderConfig.configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("transpaste-tests-\(UUID().uuidString)/providers.json")

        if let filter = TestKit.filter {
            print("Running tests matching \"\(filter)\"\n")
        }
        runTranslationServiceTests()
        runInputMonitorTests()
        runLoggerTests()
        runAppInfoTests()
        runMessagesTests()
        TestKit.summaryAndExit()
    }
}
