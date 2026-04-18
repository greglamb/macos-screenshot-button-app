import AppKit
import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("OverlayView")
struct OverlayViewTests {
    @Test("acceptsFirstMouse(for:) returns true so a single click registers on nonactivating panels")
    func acceptsFirstMouseIsTrue() throws {
        let screen = try #require(NSScreen.main)
        let view = OverlayView(screen: screen, manager: Self.makeManager())
        #expect(view.acceptsFirstMouse(for: nil) == true)
    }

    @Test(
        "Tracking area includes .cursorUpdate so cursorUpdate(with:) is called as the cursor moves — needed to keep the mode-cursor sticky on nonactivating panels across displays")
    func trackingAreaIncludesCursorUpdate() throws {
        let screen = try #require(NSScreen.main)
        let view = OverlayView(screen: screen, manager: Self.makeManager())
        view.updateTrackingAreas()
        let hasCursorUpdate = view.trackingAreas.contains { $0.options.contains(.cursorUpdate) }
        #expect(hasCursorUpdate == true)
    }

    private static func makeManager() -> OverlayManager {
        let controller = CaptureController(
            enumerator: FakeSCShareableContent(result: .success([])),
            capturer: Capturer(manager: FakeScreenshotManager()),
            fileSink: FileSink(
                writer: FakeFileWriter(),
                opener: FakePreviewOpener(),
                nowProvider: { Date(timeIntervalSince1970: 0) },
                tempDirectoryProvider: { URL(fileURLWithPath: NSTemporaryDirectory()) }
            ),
            clipboardSink: ClipboardSink(pasteboard: FakePasteboard())
        )
        return OverlayManager(controller: controller, notifier: FakeNotifying())
    }
}
