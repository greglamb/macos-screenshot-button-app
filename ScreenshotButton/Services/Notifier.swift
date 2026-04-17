import Foundation
import UserNotifications

@MainActor
final class Notifier: NSObject, Notifying {
    private var didRequestAuth = false
    private let opener: any URLOpening
    nonisolated static let openSettingsAction = "OPEN_SCREEN_RECORDING_SETTINGS"
    nonisolated static let permissionCategory = "PERMISSION_DENIED"
    nonisolated static let plainCategory = "PLAIN"

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    init(opener: any URLOpening = SystemURLOpener()) {
        self.opener = opener
        super.init()
        let openSettings = UNNotificationAction(
            identifier: Self.openSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let permission = UNNotificationCategory(
            identifier: Self.permissionCategory,
            actions: [openSettings],
            intentIdentifiers: [],
            options: []
        )
        let plain = UNNotificationCategory(
            identifier: Self.plainCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([permission, plain])
        UNUserNotificationCenter.current().delegate = self
    }

    func post(title: String, body: String) {
        Task { [weak self] in
            await self?.requestAuthorization()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = Self.plainCategory
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    func postPermissionDenied() {
        Task { [weak self] in
            await self?.requestAuthorization()
            let content = UNMutableNotificationContent()
            content.title = "Screen Recording permission required"
            content.body =
                "ScreenshotButton needs Screen Recording access in System Settings to capture windows and regions."
            content.categoryIdentifier = Self.permissionCategory
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    func requestAuthorization() async {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Test-visible seam for delegate action routing. `UNNotificationResponse.init`
    /// is private, so we test the routing logic by calling this directly.
    func handle(actionIdentifier: String) async {
        if actionIdentifier == Self.openSettingsAction {
            opener.open(Self.screenRecordingSettingsURL)
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handle(actionIdentifier: response.actionIdentifier)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
