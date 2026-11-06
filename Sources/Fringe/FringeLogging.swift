//
//  FringeLogging.swift
//  Fringe
//

import AppKit
import Foundation
import os
import UniformTypeIdentifiers
import DroppyKit

public final class FringeRotatingFileLogSink: @unchecked Sendable {
    public static let shared = FringeRotatingFileLogSink()

    public static var defaultLogDirectory: URL {
        let libraryLogs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return libraryLogs.appendingPathComponent("Logs/Fringe")
    }

    private let logDirectory: URL
    private let fileName: String = "fringe.log"
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB
    private let maxBackups: Int = 3
    private let maxLogAgeDays: TimeInterval = 7 // Auto-purge logs older than 7 days

    private let queue = DispatchQueue(
        label: "app.getdroppy.droplet.fringe.log",
        qos: .utility
    )
    private var fileHandle: FileHandle?
    private var currentFileSize: UInt64 = 0

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public init(logDirectory: URL? = nil) {
        self.logDirectory = logDirectory ?? Self.defaultLogDirectory
        queue.sync {
            self.prepareLogFile()
            self.purgeOlderLogs()
        }
    }

    public static func setup() {
        _ = shared
    }

    private func prepareLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        let url = currentFileURL
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: url)
        if let handle = fileHandle {
            currentFileSize = (try? handle.seekToEnd()) ?? 0
        }
    }

    /// Auto-purge log files older than `maxLogAgeDays` or beyond `maxBackups`
    public func purgeOlderLogs() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoffDate = Date().addingTimeInterval(-(maxLogAgeDays * 86400))

        for file in files {
            let name = file.lastPathComponent
            guard name.hasPrefix("fringe") && name.hasSuffix(".log") else { continue }
            // Do not delete current active log file here
            if name == fileName { continue }

            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let modDate = attributes[.modificationDate] as? Date,
               modDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func record(date: Date = Date(), level: String, message: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let formattedDate = self.dateFormatter.string(from: date)
            let line = "\(formattedDate) [\(level)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            self.write(data)
        }
    }

    public func flush() {
        queue.sync {
            try? fileHandle?.synchronize()
        }
    }

    private var currentFileURL: URL {
        logDirectory.appendingPathComponent(fileName)
    }

    private func backupFileURL(index: Int) -> URL {
        logDirectory.appendingPathComponent("fringe.\(index).log")
    }

    private func write(_ data: Data) {
        guard let fileHandle else { return }
        if currentFileSize + UInt64(data.count) > maxFileSize {
            rotate()
        }
        fileHandle.write(data)
        currentFileSize += UInt64(data.count)
    }

    private func rotate() {
        try? fileHandle?.synchronize()
        try? fileHandle?.close()
        fileHandle = nil

        let fileManager = FileManager.default
        let oldestBackup = backupFileURL(index: maxBackups)
        if fileManager.fileExists(atPath: oldestBackup.path) {
            try? fileManager.removeItem(at: oldestBackup)
        }

        for i in stride(from: maxBackups - 1, through: 1, by: -1) {
            let source = backupFileURL(index: i)
            let dest = backupFileURL(index: i + 1)
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.moveItem(at: source, to: dest)
            }
        }

        let firstBackup = backupFileURL(index: 1)
        if fileManager.fileExists(atPath: currentFileURL.path) {
            try? fileManager.moveItem(at: currentFileURL, to: firstBackup)
        }

        purgeOlderLogs()
        prepareLogFile()
    }
}

public enum FringeLog {
    private static let logger = Logger(subsystem: "app.getdroppy.droplet.fringe", category: "Engine")

    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
        FringeRotatingFileLogSink.shared.record(level: "DEBUG", message: message)
    }

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        FringeRotatingFileLogSink.shared.record(level: "INFO", message: message)
    }

    public static func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        FringeRotatingFileLogSink.shared.record(level: "NOTICE", message: message)
    }

    public static func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
        FringeRotatingFileLogSink.shared.record(level: "WARNING", message: message)
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        FringeRotatingFileLogSink.shared.record(level: "ERROR", message: message)
    }
}

@MainActor
public enum FringeLogExporter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func exportLogs(
        from directory: URL = FringeRotatingFileLogSink.defaultLogDirectory,
        date: Date = Date()
    ) async throws -> URL {
        FringeRotatingFileLogSink.shared.flush()

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let mainLogURL = directory.appendingPathComponent("fringe.log")
        if !fileManager.fileExists(atPath: mainLogURL.path) {
            FringeLog.info("Log session initialized for export")
            FringeRotatingFileLogSink.shared.flush()
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let logFiles = contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("fringe") && name.hasSuffix(".log")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !logFiles.isEmpty else {
            throw NSError(domain: "FringeLogExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No log files found to export."])
        }

        let dateString = dateFormatter.string(from: date)
        let archiveURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("Fringe-Logs-\(dateString).zip")
        if fileManager.fileExists(atPath: archiveURL.path) {
            try? fileManager.removeItem(at: archiveURL)
        }

        // Foundation zips the folder itself (a coordinated read "for
        // uploading"), so no process is started inside Droppy. Off the main
        // thread: it reads and compresses every log file.
        try await Task.detached(priority: .utility) {
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinationError) { zipURL in
                do {
                    try FileManager.default.copyItem(at: zipURL, to: archiveURL)
                } catch {
                    copyError = error
                }
            }
            if let error = coordinationError ?? copyError { throw error }
        }.value

        guard fileManager.fileExists(atPath: archiveURL.path) else {
            throw NSError(domain: "FringeLogExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "The log archive was not created."])
        }
        return archiveURL
    }

    public static func showLogsInFinder(directory: URL = FringeRotatingFileLogSink.defaultLogDirectory) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            FringeLog.info("Created logs directory")
            FringeRotatingFileLogSink.shared.flush()
        }
        let currentLog = directory.appendingPathComponent("fringe.log")
        if fileManager.fileExists(atPath: currentLog.path) {
            NSWorkspace.shared.selectFile(currentLog.path, inFileViewerRootedAtPath: directory.path)
        } else {
            NSWorkspace.shared.open(directory)
        }
    }
}

extension DropletKeyboardShortcut {
    /// The shortcut as Droppy's Shortcuts page writes it, for the settings row.
    var displayString: String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }

        result += Self.keyName(for: keyCode)
        return result
    }

    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key \(keyCode)"
        }
    }
}
