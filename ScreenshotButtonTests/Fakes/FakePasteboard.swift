import AppKit

@testable import ScreenshotButton

@MainActor
final class FakePasteboard: PasteboardWriting {
    var cleared = false
    var writtenImages: [NSImage] = []

    nonisolated init() {}

    func clearContents() { cleared = true }
    func write(_ image: NSImage) { writtenImages.append(image) }
}
