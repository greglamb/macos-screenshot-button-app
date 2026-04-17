import Foundation

@MainActor
struct AutolaunchToggleHandler {
    let launchAtLogin: LaunchAtLogin
    let notifier: any Notifying

    /// Attempts to set the enabled state. Returns the authoritative post-change
    /// value — equal to `enabled` on success, or the unchanged current state on
    /// failure. On failure, posts an explanatory notification via `notifier`.
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            try launchAtLogin.setEnabled(enabled)
            return enabled
        } catch {
            notifier.post(
                title: "Couldn't update Launch at Login",
                body: "Try again in a moment. If the problem persists, open System Settings → General → Login Items."
            )
            return launchAtLogin.isEnabled
        }
    }
}
