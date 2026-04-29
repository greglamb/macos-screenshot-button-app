import AppKit
import SwiftUI

struct MenuView: View {
    let launchAtLogin: LaunchAtLogin
    let notifier: any Notifying
    let onCaptureRequested: (CaptureMode, SinkKind) -> Void
    @State private var launchAtLoginEnabled: Bool

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
        // SettingsLink opens the Settings scene window using SwiftUI's
        // blessed plumbing, but for LSUIElement=true apps (.accessory
        // activation policy) it doesn't activate the app, so the window
        // opens behind other apps. Pair with simultaneousGesture to
        // activate on tap. Pure NSApp.sendAction(showSettingsWindow:)
        // does not reach the SwiftUI Settings handler from a MenuBarExtra
        // menu — only SettingsLink's internal mechanism creates the window.
        SettingsLink { Text("Settings…") }
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
            })
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
