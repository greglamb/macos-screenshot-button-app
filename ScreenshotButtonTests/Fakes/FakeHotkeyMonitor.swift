import Foundation

@testable import ScreenshotButton

@MainActor
final class FakeHotkeyMonitor: HotkeyMonitoring {
    var nextOutcome: ApplyOutcome = .applied
    private(set) var applyCalls: [HotkeyBinding?] = []

    func apply(binding: HotkeyBinding?) -> ApplyOutcome {
        applyCalls.append(binding)
        return nextOutcome
    }
}
