import Testing
import Foundation
@testable import ScreenshotButton

@Suite("TempCleanup", .tags(.fileSystem))
struct TempCleanupTests {
    @Test("Deletes files older than the cutoff and keeps fresh ones")
    func pruneDeletesFilesOlderThanCutoff() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("TempCleanupTests-\(UUID())", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let old = dir.appendingPathComponent("old.png")
        let fresh = dir.appendingPathComponent("fresh.png")
        try Data().write(to: old)
        try Data().write(to: fresh)

        // Backdate `old` to 48h ago.
        let twoDaysAgo = Date(timeIntervalSinceNow: -60 * 60 * 48)
        try fm.setAttributes([.modificationDate: twoDaysAgo], ofItemAtPath: old.path)

        TempCleanup.prune(directory: dir, olderThan: 60 * 60 * 24, fileManager: fm, now: Date())

        #expect(!fm.fileExists(atPath: old.path))
        #expect(fm.fileExists(atPath: fresh.path))
    }

    @Test("Is a silent no-op when the directory does not exist")
    func pruneIsNoOpWhenDirectoryMissing() {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID())", isDirectory: true)
        TempCleanup.prune(directory: dir, olderThan: 60, fileManager: fm, now: Date())
        // Verify the directory still doesn't exist (i.e. prune didn't accidentally create it).
        #expect(!fm.fileExists(atPath: dir.path))
    }
}
