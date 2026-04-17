import AppKit

@MainActor
final class SystemPasteboard: PasteboardWriting {
    let underlying: NSPasteboard

    init(_ underlying: NSPasteboard = .general) {
        self.underlying = underlying
    }

    func clearContents() {
        underlying.clearContents()
    }

    func write(_ image: NSImage) {
        underlying.writeObjects([image])
    }
}
