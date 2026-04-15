import Foundation

@MainActor
protocol FileWriting {
    func write(_ data: Data, to url: URL) throws
    func createDirectory(at url: URL) throws
}

@MainActor
struct SystemFileWriter: FileWriting {
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
