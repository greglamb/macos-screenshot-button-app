import AppKit
import ApplicationServices
import os

private let hotkeyLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "hotkey")

/// Returns true when Accessibility is granted, triggering the system prompt on
/// the first call. The string `"AXTrustedCheckOptionPrompt"` is the stable
/// value of `kAXTrustedCheckOptionPrompt` (verified via AXUIElement.h); using
/// the literal avoids touching the C global, which Swift 6 strict concurrency
/// treats as shared mutable state because it is typed as `var CFStringRef` in
/// the C header.
private nonisolated func axIsTrustedWithPrompt() -> Bool {
    let options: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

@MainActor
final class HotkeyMonitor: HotkeyMonitoring {
    // nonisolated(unsafe): mutated only on @MainActor (in apply(binding:));
    // accessed outside the actor only from deinit, where NSEvent.removeMonitor
    // is safe to call from any context. The MainActor reads inside apply are
    // not the reason for the escape hatch.
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

        // Probe Accessibility permission. NSEvent.addGlobalMonitorForEvents
        // for keyboard events requires Accessibility per Apple's docs:
        // "Key-related events may only be monitored if accessibility is
        // enabled or if your application is trusted for accessibility access."
        // Setting kAXTrustedCheckOptionPrompt = true shows the system prompt
        // (non-blocking) on first call when the app is not yet trusted; the
        // user must then add the app via System Settings → Privacy &
        // Security → Accessibility. Subsequent apply() calls succeed once
        // granted.
        guard axIsTrustedWithPrompt() else {
            hotkeyLog.info("Accessibility denied")
            return .permissionDenied
        }

        let keyCode = binding.keyCode
        let label = binding.label
        token = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            // Reject only "real" user modifiers (Cmd, Opt, Ctrl, Shift).
            // Fn is a keyboard-layer shift on default Apple keyboards
            // (Fn+F12 is how the user produces F12 keyDown when F-keys are
            // mapped to media); CapsLock, NumericPad, Help are not
            // user-meaningful modifier intents for hotkeys. Allow all
            // through.
            let bannedMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.keyCode == keyCode,
                  event.modifierFlags.intersection(bannedMods).isEmpty else { return }
            // The closure is invoked off-main from NSEvent's machinery;
            // hop to @MainActor before calling onFire (Swift 6 strict
            // concurrency).
            Task { @MainActor [weak self] in
                hotkeyLog.info("hotkey fired")
                self?.onFire()
            }
        }
        hotkeyLog.info("registered hotkey \(label, privacy: .public)")
        return .applied
    }
}
