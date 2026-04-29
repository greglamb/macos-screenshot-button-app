import AppKit
import os
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
            Image(systemName:
                controller.session.state == .idle
                    ? "camera.metering.center.weighted"
                    : "viewfinder"
            )
                .accessibilityLabel(
                    controller.session.state == .idle
                        ? "ScreenshotButton"
                        : "ScreenshotButton — capturing"
                )
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
                .onReceive(
                    NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
                ) { note in
                    // Revert to .accessory (no Dock icon) when the Settings
                    // window closes. MenuView sets policy to .regular when
                    // "Settings…" is tapped so the window can surface above
                    // other apps; revert here when Settings is dismissed.
                    // Filter: any non-OverlayPanel window with a content
                    // view controller is the SwiftUI Settings window
                    // (overlay panels are NSPanel; their contentView is
                    // set, not contentViewController). onReceive's closure
                    // is delivered on the main actor by SwiftUI; this
                    // avoids the Swift 6 strict-concurrency Sendable issue
                    // with NotificationCenter.notifications(named:) async
                    // sequence (Notification? is non-Sendable in CI's
                    // Swift toolchain, even though notification.object
                    // access is safe on main).
                    guard let win = note.object as? NSWindow,
                          !(win is OverlayPanel),
                          win.contentViewController != nil
                    else { return }
                    Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "menu")
                        .info("Settings closed; reverting activation policy to .accessory")
                    NSApp.setActivationPolicy(.accessory)
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
