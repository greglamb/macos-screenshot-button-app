import CoreGraphics
import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("FileSink")
struct FileSinkTests {
    @Test(
        "Writes a PNG and asks the opener to open it",
        .tags(.fileSystem, .slow),
        .timeLimit(.minutes(1)))
    func fileSinkWritesPngThenOpensInPreview() async throws {
        let writer = FakeFileWriter()
        let opener = FakePreviewOpener()
        let sink = FileSink(
            writer: writer,
            opener: opener,
            nowProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let image = FakeScreenshotManager.makeDummy()
        let url = try await sink.deliver(image)

        #expect(writer.writtenURL == url)
        #expect(url.lastPathComponent.hasPrefix("ScreenshotButton-"))
        #expect(url.lastPathComponent.hasSuffix(".png"))
        #expect(opener.openedURL == url)
    }
}
