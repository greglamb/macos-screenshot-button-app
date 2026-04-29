import Foundation

@MainActor
protocol HotkeyMonitoring: AnyObject {
    /// Apply a binding. `nil` removes any active monitor and returns `.applied`.
    /// On first call with a non-nil binding, may prompt for Accessibility permission.
    func apply(binding: HotkeyBinding?) -> ApplyOutcome
}

enum ApplyOutcome: Sendable, Equatable {
    case applied             // monitor active for the binding (or removed if nil)
    case permissionDenied    // Accessibility not granted; no monitor registered
}
