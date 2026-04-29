import SwiftUI

@main
struct ScreenshotButtonApp: App {
    @State private var controller: CaptureController
    @State private var overlays: OverlayManager
    @State private var hotkeySettings: HotkeySettingsViewModel
    private let launchAtLogin = LaunchAtLogin()
    private let notifier = Notifier()

    init() {
        let controller = CaptureController.live()
        let overlays = OverlayManager(controller: controller, notifier: notifier)
        let hotkey = HotkeyMonitor { [overlays] in
            overlays.begin(mode: .area, sink: .toClipboard)
        }
        let settings = HotkeySettingsViewModel(
            monitor: hotkey,
            defaults: .standard,
            opener: SystemURLOpener(),
            notifier: notifier
        )
        _controller = State(initialValue: controller)
        _overlays = State(initialValue: overlays)
        _hotkeySettings = State(initialValue: settings)
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
                    // Fire auth, temp cleanup, and hotkey-monitor application concurrently:
                    // a stalled permission prompt must not delay any of them.
                    async let auth: Void = notifier.requestAuthorization()
                    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(FileSink.folderName, isDirectory: true)
                    TempCleanup.prune(directory: dir, olderThan: 60 * 60 * 24)
                    await hotkeySettings.start()
                    _ = await auth
                }
        }

        Settings {
            SettingsView(viewModel: hotkeySettings)
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
