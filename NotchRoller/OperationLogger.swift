//
//  OperationLogger.swift
//  notchEye
//
//  Records user/system operations to a persistent log file (log.txt).
//  Respects a global enable flag stored in UserDefaults ("loggingEnabled").
//

import Foundation
import AppKit
import Combine

enum OperationLogCategory: String {
    case crud       = "CRUD"
    case trigger    = "TRIGGER"
    case panel      = "PANEL"
    case lifecycle  = "LIFECYCLE"
}

struct OperationLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: OperationLogCategory
    let message: String
}

@MainActor
final class OperationLogger: ObservableObject {

    static let shared = OperationLogger()

    /// UserDefaults key for the global enable/disable toggle.
    static let enableKey = "loggingEnabled"

    /// Persistent log file location: ~/Library/Application Support/notech/log.txt
    let fileURL: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("notech", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("log.txt")
    }()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private init() {}

    /// Whether logging is currently enabled (reads from UserDefaults each call
    /// so @AppStorage changes are reflected immediately).
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enableKey) as? Bool ?? true
    }

    // MARK: - Public API

    func log(_ category: OperationLogCategory, _ message: String) {
        guard isEnabled else { return }
        let ts = Date()
        let line = "[\(dateFormatter.string(from: ts))] [\(category.rawValue)] \(message)\n"
        appendToFile(line)
    }

    /// Clear the on-disk log file.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Reveal the log file in Finder.
    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    /// Reveal the log file in Finder. App Sandbox allows this even though it
    /// blocks direct writes to user-chosen destinations (which would also make
    /// NSSavePanel/NSSavePanel-style export unreliable here). The user can copy
    /// the file from Finder to wherever they want.
    @discardableResult
    func exportLog() -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        return true
    }

    // MARK: - File I/O

    private func appendToFile(_ line: String) {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? line.write(to: fileURL, atomically: true, encoding: .utf8)
        } else if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
}
