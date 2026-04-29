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

    func setBinding(_ new: HotkeyBinding?) {
        persist(new)
        binding = new

        let outcome = monitor.apply(binding: new)
        switch outcome {
        case .applied:
            permissionDenied = false
        case .permissionDenied:
            permissionDenied = true
            notifier.postPermissionDenied(kind: .inputMonitoring)
        }
    }

    private func persist(_ value: HotkeyBinding?) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }

    /// Apply the persisted binding (if any) to the live monitor. Call once at app launch.
    /// No-op when no binding is saved — avoids the Input Monitoring permission probe entirely.
    func start() async {
        guard let binding else { return }
        let outcome = monitor.apply(binding: binding)
        switch outcome {
        case .applied:
            permissionDenied = false
        case .permissionDenied:
            permissionDenied = true
            notifier.postPermissionDenied(kind: .inputMonitoring)
        }
    }

    private static func load(from defaults: UserDefaults) -> HotkeyBinding? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }
}
