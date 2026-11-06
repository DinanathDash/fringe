import Foundation
import Testing
@testable import Fringe

@Suite("Diagnostics and Logging")
struct DiagnosticsTests {
    @Test("Log sink records messages and flushes to disk")
    func logSinkRecordsAndFlushes() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FringeLogTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sink = FringeRotatingFileLogSink(logDirectory: tempDir)
        sink.record(level: "INFO", message: "Test diagnostic message")
        sink.flush()

        let logFile = tempDir.appendingPathComponent("fringe.log")
        #expect(FileManager.default.fileExists(atPath: logFile.path))
        let content = try String(contentsOf: logFile, encoding: .utf8)
        #expect(content.contains("[INFO] Test diagnostic message"))
    }

    @Test("Log export creates a zip archive even when directory is newly created")
    func exportLogsCreatesArchive() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("FringeExportTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let archiveURL = try await FringeLogExporter.exportLogs(from: tempDir)
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        #expect(archiveURL.pathExtension == "zip")
        let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        let size = (attributes[.size] as? UInt64) ?? 0
        #expect(size > 0)
    }
}
