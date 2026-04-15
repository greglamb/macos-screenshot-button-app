import SwiftUI

@main
struct ScreenshotButtonApp: App {
    @State private var controller: CaptureController
    @State private var overlays: OverlayManager
    private let launchAtLogin = LaunchAtLogin()

    init() {
        let notifier = Notifier()
        let controller = CaptureController.live()
        _controller = State(initialValue: controller)
        _overlays = State(initialValue: OverlayManager(controller: controller, notifier: notifier))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(launchAtLogin: launchAtLogin) { mode, sink in
                overlays.begin(mode: mode, sink: sink)
            }
        } label: {
            Image(systemName: "viewfinder").accessibilityLabel("ScreenshotButton")
        }
    }
}

extension CaptureController {
    @MainActor
    static func live() -> CaptureController {
        CaptureController(
            enumerator: WindowEnumerator(),
            capturer: Capturer(manager: SCScreenshotManagerAdapter()),
            fileSink: FileSink(),
            clipboardSink: ClipboardSink()
        )
    }
}
