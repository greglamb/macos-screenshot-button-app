import AppKit

@MainActor
protocol URLOpening {
    func open(_ url: URL)
}

@MainActor
struct SystemURLOpener: URLOpening {
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
}
