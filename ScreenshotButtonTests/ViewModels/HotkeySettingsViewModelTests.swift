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

    @Test("setBinding(F5) with .applied outcome stores, persists, no banner")
    func setBindingAppliedPath() throws {
        let monitor = FakeHotkeyMonitor()
        monitor.nextOutcome = .applied
        let defaults = Self.ephemeralDefaults()
        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )
        let f5 = HotkeyBinding(fKeyNumber: 5)!

        vm.setBinding(f5)

        #expect(vm.binding == f5)
        #expect(vm.permissionDenied == false)
        #expect(monitor.applyCalls == [f5])
        #expect(notifier.permissionDeniedKinds.isEmpty)

        let stored = defaults.data(forKey: HotkeySettingsViewModel.defaultsKey)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: #require(stored))
        #expect(decoded == f5)
    }

    @Test("setBinding(F5) with .permissionDenied still persists intent and posts banner")
    func setBindingDeniedPath() throws {
        let monitor = FakeHotkeyMonitor()
        monitor.nextOutcome = .permissionDenied
        let defaults = Self.ephemeralDefaults()
        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )
        let f5 = HotkeyBinding(fKeyNumber: 5)!

        vm.setBinding(f5)

        #expect(vm.binding == f5)        // intent preserved
        #expect(vm.permissionDenied == true)
        #expect(monitor.applyCalls == [f5])
        #expect(notifier.permissionDeniedKinds == [.inputMonitoring])

        let stored = defaults.data(forKey: HotkeySettingsViewModel.defaultsKey)
        #expect(stored != nil)            // persisted despite denial
    }

    @Test("setBinding(nil) after F5 removes monitor, clears UserDefaults, clears banner")
    func setBindingClearsAfterF5() {
        let monitor = FakeHotkeyMonitor()
        let defaults = Self.ephemeralDefaults()
        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )
        let f5 = HotkeyBinding(fKeyNumber: 5)!
        monitor.nextOutcome = .applied
        vm.setBinding(f5)

        vm.setBinding(nil)

        #expect(vm.binding == nil)
        #expect(vm.permissionDenied == false)
        #expect(monitor.applyCalls == [f5, nil])
        #expect(defaults.data(forKey: HotkeySettingsViewModel.defaultsKey) == nil)
    }

    @Test("Going from denied → re-pick that succeeds clears the banner")
    func recoverFromDenialOnReSelect() {
        let monitor = FakeHotkeyMonitor()
        let defaults = Self.ephemeralDefaults()
        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )
        let f5 = HotkeyBinding(fKeyNumber: 5)!
        monitor.nextOutcome = .permissionDenied
        vm.setBinding(f5)
        #expect(vm.permissionDenied == true)

        monitor.nextOutcome = .applied
        vm.setBinding(f5)

        #expect(vm.permissionDenied == false)
    }

    @Test("start() with no saved binding does nothing")
    func startNoSavedBindingIsNoOp() async {
        let monitor = FakeHotkeyMonitor()
        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: Self.ephemeralDefaults(),
            opener: FakeURLOpener(), notifier: notifier
        )

        await vm.start()

        #expect(monitor.applyCalls.isEmpty)
        #expect(notifier.permissionDeniedKinds.isEmpty)
        #expect(vm.permissionDenied == false)
    }

    @Test("start() with saved binding and granted permission registers monitor")
    func startWithGrantedAppliesBinding() async throws {
        let monitor = FakeHotkeyMonitor()
        monitor.nextOutcome = .applied
        let defaults = Self.ephemeralDefaults()
        let f5 = HotkeyBinding(fKeyNumber: 5)!
        defaults.set(try JSONEncoder().encode(f5), forKey: HotkeySettingsViewModel.defaultsKey)

        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )

        await vm.start()

        #expect(monitor.applyCalls == [f5])
        #expect(vm.permissionDenied == false)
        #expect(notifier.permissionDeniedKinds.isEmpty)
    }

    @Test("start() with saved binding and denied permission posts banner")
    func startWithDeniedPostsBanner() async throws {
        let monitor = FakeHotkeyMonitor()
        monitor.nextOutcome = .permissionDenied
        let defaults = Self.ephemeralDefaults()
        let f5 = HotkeyBinding(fKeyNumber: 5)!
        defaults.set(try JSONEncoder().encode(f5), forKey: HotkeySettingsViewModel.defaultsKey)

        let notifier = FakeNotifying()
        let vm = HotkeySettingsViewModel(
            monitor: monitor, defaults: defaults,
            opener: FakeURLOpener(), notifier: notifier
        )

        await vm.start()

        #expect(monitor.applyCalls == [f5])
        #expect(vm.permissionDenied == true)
        #expect(notifier.permissionDeniedKinds == [.inputMonitoring])
        #expect(vm.binding == f5)   // intent preserved
    }
}
