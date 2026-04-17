import Foundation
import Testing

@testable import ScreenshotButton

private struct LaunchError: Error, Equatable {}

@MainActor
@Suite("LaunchAtLogin")
struct LaunchAtLoginTests {
    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "LaunchAtLoginTests-\(UUID())")!
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
        return defaults
    }

    @Test("Enabling registers with SMAppService and persists to UserDefaults")
    func enableRegistersAndPersists() throws {
        let defaults = makeDefaults()
        let api = FakeSMAppServiceAPI(initialStatus: .notRegistered)
        let la = LaunchAtLogin(api: api, defaults: defaults)

        try la.setEnabled(true)

        #expect(api.registerCalls == 1)
        #expect(defaults.bool(forKey: LaunchAtLogin.defaultsKey) == true)
        #expect(la.isEnabled == true)
    }

    @Test("Disabling unregisters and clears the persisted flag")
    func disableUnregistersAndPersists() throws {
        let defaults = makeDefaults()
        defaults.set(true, forKey: LaunchAtLogin.defaultsKey)
        let api = FakeSMAppServiceAPI(initialStatus: .enabled)
        let la = LaunchAtLogin(api: api, defaults: defaults)

        try la.setEnabled(false)

        #expect(api.unregisterCalls == 1)
        #expect(defaults.bool(forKey: LaunchAtLogin.defaultsKey) == false)
    }

    @Test("A registration failure propagates and leaves the persisted flag untouched")
    func registrationFailurePropagates() {
        let defaults = makeDefaults()
        let api = FakeSMAppServiceAPI(initialStatus: .notRegistered)
        api.registerError = LaunchError()
        let la = LaunchAtLogin(api: api, defaults: defaults)

        #expect(throws: LaunchError.self) {
            try la.setEnabled(true)
        }
        #expect(defaults.bool(forKey: LaunchAtLogin.defaultsKey) == false)
    }
}
