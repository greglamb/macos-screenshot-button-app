import Foundation

@MainActor
final class LaunchAtLogin {
    static let defaultsKey = "dev.greglamb.ScreenshotButton.launchAtLogin"

    private let api: any SMAppServiceAPI
    private let defaults: UserDefaults

    init(api: any SMAppServiceAPI = SystemSMAppService(), defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
    }

    var isEnabled: Bool {
        defaults.bool(forKey: Self.defaultsKey)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try api.register()
        } else {
            try api.unregister()
        }
        defaults.set(enabled, forKey: Self.defaultsKey)
    }
}
