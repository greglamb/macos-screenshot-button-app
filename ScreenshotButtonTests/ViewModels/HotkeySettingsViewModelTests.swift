import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("HotkeySettingsViewModel")
struct HotkeySettingsViewModelTests {

    private static func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    @Test("Initialised with no saved binding starts as nil")
    func freshDefaultsHasNilBinding() {
        let vm = HotkeySettingsViewModel(
            monitor: FakeHotkeyMonitor(),
            defaults: Self.ephemeralDefaults(),
            opener: FakeURLOpener(),
            notifier: FakeNotifying()
        )
        #expect(vm.binding == nil)
        #expect(vm.permissionDenied == false)
    }

    @Test("Initialised from a previously persisted binding loads it")
    func loadsPersistedBinding() throws {
        let defaults = Self.ephemeralDefaults()
        let f5 = HotkeyBinding(fKeyNumber: 5)!
        let data = try JSONEncoder().encode(f5)
        defaults.set(data, forKey: HotkeySettingsViewModel.defaultsKey)

        let vm = HotkeySettingsViewModel(
            monitor: FakeHotkeyMonitor(),
            defaults: defaults,
            opener: FakeURLOpener(),
            notifier: FakeNotifying()
        )

        #expect(vm.binding == f5)
    }

    @Test("Initialised from a corrupted UserDefaults entry treats as nil")
    func corruptDefaultsTreatedAsNil() {
        let defaults = Self.ephemeralDefaults()
        defaults.set(Data([0x00, 0xFF, 0xFE]), forKey: HotkeySettingsViewModel.defaultsKey)

        let vm = HotkeySettingsViewModel(
            monitor: FakeHotkeyMonitor(),
            defaults: defaults,
            opener: FakeURLOpener(),
            notifier: FakeNotifying()
        )

        #expect(vm.binding == nil)
    }
}
