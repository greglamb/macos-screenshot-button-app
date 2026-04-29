import Foundation
import UserNotifications

@MainActor
final class Notifier: NSObject, Notifying {
    private var didRequestAuth = false
    private let opener: any URLOpening

    nonisolated static let openScreenRecordingSettingsAction = "OPEN_SCREEN_RECORDING_SETTINGS"
    nonisolated static let openAccessibilitySettingsAction = "OPEN_ACCESSIBILITY_SETTINGS"
    nonisolated static let screenRecordingCategory = "PERMISSION_DENIED_SCREEN_RECORDING"
    nonisolated static let accessibilityCategory = "PERMISSION_DENIED_ACCESSIBILITY"
    nonisolated static let plainCategory = "PLAIN"

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!
    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    init(opener: any URLOpening = SystemURLOpener()) {
        self.opener = opener
        super.init()
        let openScreenRecording = UNNotificationAction(
            identifier: Self.openScreenRecordingSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let openAccessibility = UNNotificationAction(
            identifier: Self.openAccessibilitySettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let screenRecording = UNNotificationCategory(
            identifier: Self.screenRecordingCategory,
            actions: [openScreenRecording],
            intentIdentifiers: [],
            options: []
        )
        let accessibility = UNNotificationCategory(
            identifier: Self.accessibilityCategory,
            actions: [openAccessibility],
            intentIdentifiers: [],
            options: []
        )
        let plain = UNNotificationCategory(
            identifier: Self.plainCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories(
            [screenRecording, accessibility, plain]
        )
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

    func postPermissionDenied(kind: PermissionKind) {
        Task { [weak self] in
            await self?.requestAuthorization()
            let content = UNMutableNotificationContent()
            switch kind {
            case .screenRecording:
                content.title = "Screen Recording permission required"
                content.body = "ScreenshotButton needs Screen Recording access in System Settings to capture windows and regions."
                content.categoryIdentifier = Self.screenRecordingCategory
            case .accessibility:
                content.title = "Accessibility permission required"
                content.body = "ScreenshotButton needs Accessibility access in System Settings to receive global hotkeys."
                content.categoryIdentifier = Self.accessibilityCategory
            }
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

    func handle(actionIdentifier: String) async {
        switch actionIdentifier {
        case Self.openScreenRecordingSettingsAction:
            opener.open(Self.screenRecordingSettingsURL)
        case Self.openAccessibilitySettingsAction:
            opener.open(Self.accessibilitySettingsURL)
        default:
            break
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
