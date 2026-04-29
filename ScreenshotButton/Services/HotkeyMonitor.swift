import AppKit
import IOKit.hid
import os

private let hotkeyLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "hotkey")

@MainActor
final class HotkeyMonitor: HotkeyMonitoring {
    // nonisolated(unsafe): written only on @MainActor via apply(binding:);
    // read only in deinit for cleanup. NSEvent.removeMonitor is safe to call
    // from any context, so relaxing isolation here is correct.
    nonisolated(unsafe) private var token: Any?
    private var currentBinding: HotkeyBinding?
    private let onFire: @MainActor () -> Void

    init(onFire: @escaping @MainActor () -> Void) {
        self.onFire = onFire
    }

    deinit {
        if let token { NSEvent.removeMonitor(token) }
    }

    func apply(binding: HotkeyBinding?) -> ApplyOutcome {
        // Always remove any existing monitor first.
        if let existing = token {
            NSEvent.removeMonitor(existing)
            token = nil
        }
        currentBinding = binding

        guard let binding else {
            hotkeyLog.info("hotkey cleared")
            return .applied
        }

        // Probe Input Monitoring permission. Prompt on first call.
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            break
        case kIOHIDAccessTypeUnknown:
            // Synchronous prompt; returns true on grant.
            if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
                hotkeyLog.info("Input Monitoring denied (post-prompt)")
                return .permissionDenied
            }
        default:
            hotkeyLog.info("Input Monitoring denied")
            return .permissionDenied
        }

        let keyCode = binding.keyCode
        let label = binding.label
        token = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            // Strict no-modifiers match (v1 spec).
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == keyCode, mods.isEmpty else { return }
            // The closure is delivered on the main thread by NSEvent for global monitors,
            // but @Sendable closure capture rules mean we explicitly hop:
            Task { @MainActor [weak self] in
                hotkeyLog.info("hotkey fired")
                self?.onFire()
            }
        }
        hotkeyLog.info("registered hotkey \(label, privacy: .public)")
        return .applied
    }
}
