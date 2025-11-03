import Foundation

class LogManager {
    private let logsFileURL: URL

    init() {
        // Store logs.json in the project directory
        // For now, we'll use the application support directory as project directory may not be writable
        let projectPath = FileManager.default.currentDirectoryPath
        logsFileURL = URL(fileURLWithPath: projectPath).appendingPathComponent("logs.json")

        // Create empty array if file doesn't exist
        if !FileManager.default.fileExists(atPath: logsFileURL.path) {
            createEmptyLogsFile()
        }
    }

    private func createEmptyLogsFile() {
        let emptyArray: [[String: String]] = []
        if let data = try? JSONEncoder().encode(emptyArray) {
            try? data.write(to: logsFileURL)
        }
    }

    func log(text: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry: [String: String] = [
            "timestamp": timestamp,
            "text": text
        ]

        // Read existing logs
        var logs: [[String: String]] = []
        if let data = try? Data(contentsOf: logsFileURL),
           let existingLogs = try? JSONDecoder().decode([[String: String]].self, from: data) {
            logs = existingLogs
        }

        // Append new entry
        logs.append(entry)

        // Write back to file
        if let data = try? JSONEncoder().encode(logs) {
            do {
                try data.write(to: logsFileURL, options: .atomic)
                print("Logged to: \(logsFileURL.path)")
            } catch {
                print("Error writing log: \(error)")
            }
        }
    }
}
