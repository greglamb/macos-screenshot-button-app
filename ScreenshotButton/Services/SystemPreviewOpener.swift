import AppKit

@MainActor
struct SystemPreviewOpener: PreviewOpening {
    func open(_ url: URL) async throws {
        let preview = URL(fileURLWithPath: "/System/Applications/Preview.app")
        _ = try await NSWorkspace.shared.open(
            [url], withApplicationAt: preview, configuration: .init())
    }
}
