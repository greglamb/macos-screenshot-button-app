import Foundation
import Observation

@Observable
@MainActor
final class HotkeySettingsViewModel {
    static let defaultsKey = "areaToClipboardHotkey"

    private(set) var binding: HotkeyBinding?
    private(set) var permissionDenied: Bool = false

    private let monitor: any HotkeyMonitoring
    private let defaults: UserDefaults
    private let opener: any URLOpening
    private let notifier: any Notifying

    init(monitor: any HotkeyMonitoring,
         defaults: UserDefaults,
         opener: any URLOpening,
         notifier: any Notifying) {
        self.monitor = monitor
        self.defaults = defaults
        self.opener = opener
        self.notifier = notifier
        self.binding = Self.load(from: defaults)
    }

    private static func load(from defaults: UserDefaults) -> HotkeyBinding? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }
}
