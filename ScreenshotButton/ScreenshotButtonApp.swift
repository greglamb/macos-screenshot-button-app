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
            Image(systemName: "viewfinder")
                .accessibilityLabel("ScreenshotButton")
                .task(priority: .background) {
                    // Idempotent cleanup of stale temp PNGs. Uses synchronous
                    // FileManager calls — `.task(priority:)` already gives us a
                    // background-priority async context; no nested unstructured
                    // Task needed.
                    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(FileSink.folderName, isDirectory: true)
                    TempCleanup.prune(directory: dir, olderThan: 60 * 60 * 24)
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
