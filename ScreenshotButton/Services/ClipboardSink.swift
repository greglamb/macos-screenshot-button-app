import AppKit
import CoreGraphics

@MainActor
struct ClipboardSink {
    let pasteboard: any PasteboardWriting

    init(pasteboard: any PasteboardWriting = SystemPasteboard()) {
        self.pasteboard = pasteboard
    }

    func deliver(_ image: CGImage) {
        pasteboard.clearContents()
        let ns = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        pasteboard.write(ns)
    }
}
