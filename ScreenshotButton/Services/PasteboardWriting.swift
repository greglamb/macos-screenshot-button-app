import AppKit

@MainActor
protocol PasteboardWriting: AnyObject {
    func clearContents()
    func write(_ image: NSImage)
}
