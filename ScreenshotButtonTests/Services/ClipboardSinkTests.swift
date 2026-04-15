import Testing
import AppKit
@testable import ScreenshotButton

@MainActor
@Suite("ClipboardSink")
struct ClipboardSinkTests {
    @Test("Clears the pasteboard then writes the image")
    func clipboardSinkWritesAnImage() {
        let pb = FakePasteboard()
        let sink = ClipboardSink(pasteboard: pb)
        let image = FakeScreenshotManager.makeDummy()
        sink.deliver(image)
        #expect(pb.cleared)
        #expect(pb.writtenImages.count == 1)
    }
}
