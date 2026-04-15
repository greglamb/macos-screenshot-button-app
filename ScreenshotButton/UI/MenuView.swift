import SwiftUI
import AppKit

struct MenuView: View {
    let launchAtLogin: LaunchAtLogin
    let onCaptureRequested: (CaptureMode, SinkKind) -> Void
    @State private var launchAtLoginEnabled: Bool

    init(
        launchAtLogin: LaunchAtLogin,
        onCaptureRequested: @escaping (CaptureMode, SinkKind) -> Void
    ) {
        self.launchAtLogin = launchAtLogin
        self.onCaptureRequested = onCaptureRequested
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Button("Window to File")      { onCaptureRequested(.window, .toFile) }
        Button("Area to File")        { onCaptureRequested(.area,   .toFile) }
        Divider()
        Button("Window to Clipboard") { onCaptureRequested(.window, .toClipboard) }
        Button("Area to Clipboard")   { onCaptureRequested(.area,   .toClipboard) }
        Divider()
        Toggle("Autolaunch", isOn: $launchAtLoginEnabled)
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                do {
                    try launchAtLogin.setEnabled(newValue)
                } catch {
                    // Revert silently — the SMAppService failure is rare and
                    // the user can try again. Future: surface via Notifier.
                    launchAtLoginEnabled = launchAtLogin.isEnabled
                }
            }
        Divider()
        Button("Quit ScreenshotButton") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
