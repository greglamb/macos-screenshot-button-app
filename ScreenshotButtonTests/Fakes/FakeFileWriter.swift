import Foundation
@testable import ScreenshotButton

@MainActor
final class FakeFileWriter: FileWriting {
    var writtenURL: URL?
    var writtenData: Data?
    var createdDirectories: [URL] = []

    nonisolated init() {}

    func write(_ data: Data, to url: URL) throws {
        writtenURL = url
        writtenData = data
    }
    func createDirectory(at url: URL) throws {
        createdDirectories.append(url)
    }
}
