import AppKit
import SwiftUI

struct MenuView: View {
    let launchAtLogin: LaunchAtLogin
    let notifier: any Notifying
    let onCaptureRequested: (CaptureMode, SinkKind) -> Void
    @State private var launchAtLoginEnabled: Bool
    @Environment(\.openSettings) private var openSettings

    init(
        launchAtLogin: LaunchAtLogin,
        notifier: any Notifying,
        onCaptureRequested: @escaping (CaptureMode, SinkKind) -> Void
    ) {
        self.launchAtLogin = launchAtLogin
        self.notifier = notifier
        self.onCaptureRequested = onCaptureRequested
        _launchAtLoginEnabled = State(initialValue: launchAtLogin.isEnabled)
    }

    var body: some View {
        Button("Window to File") { onCaptureRequested(.window, .toFile) }
        Button("Area to File") { onCaptureRequested(.area, .toFile) }
        Divider()
        Button("Window to Clipboard") { onCaptureRequested(.window, .toClipboard) }
        Button("Area to Clipboard") { onCaptureRequested(.area, .toClipboard) }
        Divider()
        Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                let handler = AutolaunchToggleHandler(launchAtLogin: launchAtLogin, notifier: notifier)
                launchAtLoginEnabled = handler.setEnabled(newValue)
            }
        Divider()
        // Use a Button + @Environment(\.openSettings) rather than
        // SettingsLink. SettingsLink's tap doesn't expose a place for our
        // own action, and simultaneousGesture does not reliably fire
        // inside a MenuBarExtra menu — the gesture closure is never
        // called. Button.action runs deterministically. For
        // LSUIElement=true apps, briefly switch to .regular activation so
        // the Settings window can surface above other apps; revert to
        // .accessory on window close (observer in ScreenshotButtonApp).
        Button("Settings…") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit ScreenshotButton") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
        Divider()
        Text("Version \(Self.versionString)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// `CFBundleShortVersionString` from the app bundle. Released builds show
    /// "1.2.3" (from the git tag → `MARKETING_VERSION`); local dev builds show
    /// "dev-abc1234" (stamped by the Project.yml postBuildScript). Falls back
    /// to "?" if neither path fires.
    private static var versionString: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    }
}
