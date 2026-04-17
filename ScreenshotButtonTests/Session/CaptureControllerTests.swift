import CoreGraphics
import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("CaptureController")
struct CaptureControllerTests {
    @Test("start() puts the session into capturing with the chosen mode and sink")
    func startSetsSessionCapturing() {
        let c = makeController()
        c.start(mode: .window, sink: .toFile)
        #expect(c.session.state == .capturing)
        #expect(c.session.mode == .window)
        #expect(c.session.sink == .toFile)
    }

    @Test(
        "commitWindow with file sink writes a file and returns to idle",
        .timeLimit(.minutes(1)))
    func commitWindowWithFileSinkWritesAndReturnsToIdle() async throws {
        let writer = FakeFileWriter()
        let opener = FakePreviewOpener()
        let c = makeController(fileWriter: writer, previewOpener: opener)
        c.start(mode: .window, sink: .toFile)

        let win = CapturedWindow(id: 1, frame: .zero, title: nil, ownerName: nil)
        try await c.commitWindow(win)

        #expect(writer.writtenURL != nil)
        #expect(opener.openedURL != nil)
        #expect(c.session.state == .idle)
    }

    @Test(
        "commitArea with clipboard sink writes to the pasteboard and returns to idle",
        .timeLimit(.minutes(1)))
    func commitAreaWithClipboardSinkCopiesAndReturnsToIdle() async throws {
        let pb = FakePasteboard()
        let c = makeController(pasteboard: pb)
        c.start(mode: .area, sink: .toClipboard)

        try await c.commitArea(CGRect(x: 0, y: 0, width: 10, height: 10), displayID: 1)

        #expect(pb.writtenImages.count == 1)
        #expect(c.session.state == .idle)
    }

    @Test("cancel() returns the session to idle")
    func cancelReturnsToIdle() {
        let c = makeController()
        c.start(mode: .window, sink: .toFile)
        c.cancel()
        #expect(c.session.state == .idle)
    }

    private func makeController(
        fileWriter: FakeFileWriter = FakeFileWriter(),
        previewOpener: FakePreviewOpener = FakePreviewOpener(),
        pasteboard: FakePasteboard = FakePasteboard()
    ) -> CaptureController {
        CaptureController(
            enumerator: FakeSCShareableContent(result: .success([])),
            capturer: Capturer(manager: FakeScreenshotManager()),
            fileSink: FileSink(
                writer: fileWriter,
                opener: previewOpener,
                nowProvider: { Date(timeIntervalSince1970: 0) },
                tempDirectoryProvider: { URL(fileURLWithPath: NSTemporaryDirectory()) }
            ),
            clipboardSink: ClipboardSink(pasteboard: pasteboard)
        )
    }
}
