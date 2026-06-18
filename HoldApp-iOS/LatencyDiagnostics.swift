//
//  LatencyDiagnostics.swift
//  HoldApp-iOS
//
//  Created by Codex on 17/06/2026.
//

import Foundation
import os

enum LatencyDiagnostics {
    #if DEBUG
    private static let logger = Logger(subsystem: "com.vishaljain.HoldApp", category: "iOS-Latency")
    private static let fileName = "latency-diagnostics.log"
    private static let writeQueue = DispatchQueue(label: "com.vishaljain.HoldApp.latencyDiagnostics")
    private static let formatter = ISO8601DateFormatter()
    private static let environmentFlag = "HOLD_IOS_LATENCY_DIAGNOSTICS"
    private static let userDefaultsFlag = "HoldLatencyDiagnosticsEnabled"
    #endif

    static func log(_ message: String) {
        #if DEBUG
        logger.debug("[LATENCY] \(message, privacy: .public)")

        guard isPersistentLoggingEnabled else {
            return
        }

        let eventDate = Date()
        writeQueue.async {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }

            let fileURL = documentsURL.appendingPathComponent(fileName)
            let line = "\(formatter.string(from: eventDate)) [LATENCY] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
        #endif
    }

    #if DEBUG
    private static var isPersistentLoggingEnabled: Bool {
        if ProcessInfo.processInfo.environment[environmentFlag] == "1" {
            return true
        }

        return UserDefaults.standard.bool(forKey: userDefaultsFlag)
    }
    #endif
}
