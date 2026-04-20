import SwiftUI

@main
struct ScreenshotButtonApp: App {
    @State private var controller: CaptureController
    @State private var overlays: OverlayManager
    private let launchAtLogin = LaunchAtLogin()
    private let notifier = Notifier()

    init() {
        let controller = CaptureController.live()
        _controller = State(initialValue: controller)
        _overlays = State(initialValue: OverlayManager(controller: controller, notifier: notifier))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(launchAtLogin: launchAtLogin, notifier: notifier) { mode, sink in
                overlays.begin(mode: mode, sink: sink)
            }
        } label: {
            Image(systemName: "camera.metering.center.weighted")
                .accessibilityLabel("ScreenshotButton")
                .task(priority: .background) {
                    // Fire auth and temp cleanup concurrently: a stalled permission prompt
                    // must not delay pruning. `async let` gives us a structured child task
                    // scoped to this `.task` modifier, so SwiftUI cancellation propagates.
                    async let auth: Void = notifier.requestAuthorization()
                    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(FileSink.folderName, isDirectory: true)
                    TempCleanup.prune(directory: dir, olderThan: 60 * 60 * 24)
                    _ = await auth
                }
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
