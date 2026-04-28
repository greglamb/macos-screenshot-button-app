import Foundation
import UserNotifications

@MainActor
final class Notifier: NSObject, Notifying {
    private var didRequestAuth = false
    private let opener: any URLOpening

    nonisolated static let openScreenRecordingSettingsAction = "OPEN_SCREEN_RECORDING_SETTINGS"
    nonisolated static let openInputMonitoringSettingsAction = "OPEN_INPUT_MONITORING_SETTINGS"
    nonisolated static let screenRecordingCategory = "PERMISSION_DENIED_SCREEN_RECORDING"
    nonisolated static let inputMonitoringCategory = "PERMISSION_DENIED_INPUT_MONITORING"
    nonisolated static let plainCategory = "PLAIN"

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!
    static let inputMonitoringSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!

    init(opener: any URLOpening = SystemURLOpener()) {
        self.opener = opener
        super.init()
        let openScreenRecording = UNNotificationAction(
            identifier: Self.openScreenRecordingSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let openInputMonitoring = UNNotificationAction(
            identifier: Self.openInputMonitoringSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let screenRecording = UNNotificationCategory(
            identifier: Self.screenRecordingCategory,
            actions: [openScreenRecording],
            intentIdentifiers: [],
            options: []
        )
        let inputMonitoring = UNNotificationCategory(
            identifier: Self.inputMonitoringCategory,
            actions: [openInputMonitoring],
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
            [screenRecording, inputMonitoring, plain]
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
            case .inputMonitoring:
                content.title = "Input Monitoring permission required"
                content.body = "ScreenshotButton needs Input Monitoring access in System Settings to receive global hotkeys."
                content.categoryIdentifier = Self.inputMonitoringCategory
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
        case Self.openInputMonitoringSettingsAction:
            opener.open(Self.inputMonitoringSettingsURL)
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
