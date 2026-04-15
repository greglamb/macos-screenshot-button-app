import Foundation

enum TempCleanup {
    static func prune(
        directory: URL,
        olderThan seconds: TimeInterval,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let cutoff = now.addingTimeInterval(-seconds)
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let entries = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in entries {
            guard
                let values = try? url.resourceValues(forKeys: Set(keys)),
                let mod = values.contentModificationDate,
                mod < cutoff
            else { continue }
            try? fileManager.removeItem(at: url)
        }
    }
}
