import Foundation

@MainActor
protocol HotkeyMonitoring: AnyObject {
    /// Apply a binding. `nil` removes any active monitor and returns `.applied`.
    /// On first call with a non-nil binding, may prompt for Input Monitoring permission.
    func apply(binding: HotkeyBinding?) -> ApplyOutcome
}

enum ApplyOutcome: Sendable, Equatable {
    case applied             // monitor active for the binding (or removed if nil)
    case permissionDenied    // Input Monitoring not granted; no monitor registered
}
