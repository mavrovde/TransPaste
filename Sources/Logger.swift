import Foundation

public class Logger {
    public static let shared = Logger()
    let logURL: URL

    // Serializes file access — log() is called from the main thread and URLSession callbacks
    private let queue = DispatchQueue(label: "com.mavrovde.transpaste.logger")
    private let formatter = ISO8601DateFormatter()

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logURL = home.appendingPathComponent("translator.log")
    }

    public func log(_ message: String) {
        let logMessage = "[\(formatter.string(from: Date()))] \(message)\n"
        queue.async {
            guard let data = logMessage.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: self.logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: self.logURL) {
                    defer { fileHandle.closeFile() }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                }
            } else {
                try? data.write(to: self.logURL)
            }
        }
    }

    /// Blocks until all pending log writes have hit the file. Used by tests.
    public func flush() {
        queue.sync {}
    }
}
