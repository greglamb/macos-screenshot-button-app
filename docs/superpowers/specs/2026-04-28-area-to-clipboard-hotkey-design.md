# Area-to-Clipboard Global Hotkey — Design

**Date:** 2026-04-28
**Status:** Approved for planning
**Scope:** v1 of the deferred "Global hotkeys" TODO entry.

---

## Goal

Add a configurable global function-key hotkey for the **Area-to-Clipboard** capture mode, configured from a new "Settings…" window opened from the menu-bar dropdown.

When a user picks an F-key (F1…F19) in Settings, pressing that key from any frontmost application starts the same per-screen area-selection overlay the existing menu entry triggers, with the result going to the system clipboard.

## Non-goals (v1)

- **Hotkeys for the other three capture modes** (Window-to-File, Area-to-File, Window-to-Clipboard). The persistence and service shape is dictionary-typed (`[CaptureCommand: HotkeyBinding]`) so adding rows is a UI-only change later, but only A→C is exposed in v1's UI.
- **Modifier keys** (⌘/⌥/⌃/⇧). v1 binding is "F-key alone, no modifiers." Pressing `Cmd+F5` is ignored; only bare F5 fires.
- **Keys other than F1–F19.** No letters, no arrow keys, no recorder UI.
- **Cross-app collision detection** ("F5 is already in use by Spotlight"). Cannot be detected with the chosen API; documented constraint.
- **Live revocation detection.** macOS doesn't notify us when TCC is revoked at runtime; we surface the denial state on the next `apply` call.

## Background

`TODO.md` lists "Global hotkeys for the four capture modes — scope-cut to keep v1 menu-only" under "Deferred from v1." This spec implements the first slice of that deferred work.

The cursor-during-capture saga from 2026-04-19/20 (preserved in `TODO.md`) is a load-bearing precedent: a feature can ship with green tests and still be silently broken if no human verifies it on real hardware. This design therefore commits to a manual-verification checklist as a release-blocking acceptance criterion, not a "nice to have."

## Architecture

### File layout

```
ScreenshotButton/
├── Core/
│   └── HotkeyBinding.swift           [NEW]  Sendable value type — F-key keyCode + label
├── Services/
│   ├── HotkeyMonitoring.swift        [NEW]  protocol + ApplyOutcome enum
│   └── HotkeyMonitor.swift           [NEW]  @MainActor live impl wrapping NSEvent global monitor
├── ViewModels/
│   └── HotkeySettingsViewModel.swift [NEW]  @Observable @MainActor — owns selection, persists, drives monitor
├── Views/
│   ├── SettingsView.swift            [NEW]  Form { Picker } + permission banner
│   └── MenuView.swift                [MOD]  add SettingsLink "Settings…" entry (Cmd-,)
└── ScreenshotButtonApp.swift         [MOD]  add Settings scene; instantiate HotkeyMonitor in init;
                                              wire fire callback to OverlayManager;
                                              call hotkeySettings.start() in menubar Image .task
```

### Tests

```
ScreenshotButtonTests/
├── Core/HotkeyBindingTests.swift                 pure-logic mapping + Codable round-trip
├── ViewModels/HotkeySettingsViewModelTests.swift setBinding paths, persistence, denied flow, start()
└── Fakes/FakeHotkeyMonitor.swift                 records apply() calls; configurable outcome
```

### Concurrency

- `HotkeyMonitor` is `@MainActor`. `NSEvent.addGlobalMonitorForEvents` and `NSEvent.removeMonitor` must run on the main thread.
- `HotkeySettingsViewModel` is `@MainActor` (project convention for ViewModels).
- `HotkeyBinding` is `Sendable` (struct of value types).
- `HotkeyMonitoring.apply` is synchronous. `IOHIDRequestAccess` is synchronous-but-prompts-the-user; calling it from the main thread during a user-initiated action (picking a Picker value) is the expected UX.

### Dependency direction

```
ScreenshotButtonApp ─┬─→ HotkeyMonitor
                     │     ↑ onFire closure → OverlayManager.begin(.area, .toClipboard)
                     ├─→ HotkeySettingsViewModel ─→ HotkeyMonitoring (protocol)
                     │                            ─→ UserDefaults
                     │                            ─→ Notifying (existing)
                     └─→ Settings { SettingsView(viewModel: hotkeySettings) }
```

`OverlayManager` does **not** know `HotkeyMonitor` exists. The hotkey is just one more caller of `begin(mode:sink:)`, identical to a menu click.

## Components

### `Core/HotkeyBinding.swift`

```swift
struct HotkeyBinding: Sendable, Hashable, Codable {
    let keyCode: UInt16          // kVK_F1 … kVK_F19
    var label: String { … }      // "F1" … "F19" (derived from keyCode)
    init?(fKeyNumber: Int)       // 1…19 → keyCode; nil for out-of-range
    static let allFKeys: [HotkeyBinding]   // F1…F19 in order, for Picker iteration
}
```

`nil` (i.e. `HotkeyBinding?`) represents "None" in both the UI and persistence. No separate enum case.

### `Services/HotkeyMonitoring.swift`

```swift
@MainActor
protocol HotkeyMonitoring: AnyObject {
    func apply(binding: HotkeyBinding?) -> ApplyOutcome
}

enum ApplyOutcome: Sendable, Equatable {
    case applied          // monitor active for the binding (or removed if nil)
    case permissionDenied // Input Monitoring not granted; no monitor registered
}
```

Single method handles all transitions: register, change, disable. `nil` ⇒ remove monitor and return `.applied`. Auto-prompts on first call via `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`; `.permissionDenied` covers both "user said no" and "still undetermined after prompt."

### `Services/HotkeyMonitor.swift`

```swift
@MainActor
final class HotkeyMonitor: HotkeyMonitoring {
    init(onFire: @escaping @MainActor () -> Void)
    func apply(binding: HotkeyBinding?) -> ApplyOutcome
    deinit { /* NSEvent.removeMonitor(token) if present */ }
}
```

- Holds the `Any?` token returned by `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`.
- Closure short-circuits unless `event.keyCode == binding.keyCode` **and** `event.modifierFlags.intersection(.deviceIndependentFlagsMask)` is empty.
- On `apply`: if a token exists, `NSEvent.removeMonitor` first, then conditionally re-register.
- Permission probe: `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`; if `.unknown`, `IOHIDRequestAccess(...)` once. Maps `.granted` → register; `.denied`/`.unknown-after-prompt` → return `.permissionDenied` without registering.

### `ViewModels/HotkeySettingsViewModel.swift`

```swift
@Observable @MainActor
final class HotkeySettingsViewModel {
    private(set) var binding: HotkeyBinding?
    private(set) var permissionDenied: Bool

    init(monitor: any HotkeyMonitoring,
         defaults: UserDefaults,
         notifier: any Notifying)

    func start() async                       // call once at app launch; applies saved binding
    func setBinding(_ new: HotkeyBinding?)   // user picked; persists, applies, posts banner if denied
    func openInputMonitoringSettings()       // opens Privacy & Security → Input Monitoring
}
```

- `init` decodes `UserDefaults["areaToClipboardHotkey"]` (JSON-encoded `HotkeyBinding?`). Malformed JSON → treat as `nil`.
- `start()` is a no-op when `binding == nil` (no permission probe, no prompt).
- `setBinding(_:)` order: persist → set observable `binding` → call `monitor.apply(...)` → on denial set `permissionDenied = true` and post `Notifier` banner; on success clear the flag.
- User intent is preserved across denials: the chosen F-key stays in `UserDefaults` and `binding` even when permission is missing. Granting permission later (and relaunching) re-arms automatically via `start()`.
- `openInputMonitoringSettings()` opens `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent` via `NSWorkspace.open(_:)`.

### `Views/SettingsView.swift`

`Form` with one `Section("Capture Hotkeys")`:

- Labeled `Picker("Area to Clipboard", selection:)` bound through a custom `Binding<HotkeyBinding?>` wrapper that routes writes to `viewModel.setBinding`. Items: `Text("None").tag(HotkeyBinding?.none)` then `ForEach(HotkeyBinding.allFKeys)`.
- When `viewModel.permissionDenied`: a row with secondary-foreground text (`"Input Monitoring is required for global hotkeys."`) and an `Open Settings` button calling `viewModel.openInputMonitoringSettings()`.
- A second `Section { Text("Tip: macOS may map F1–F12 to media keys. Hold Fn or enable F-keys-as-standard-keys in System Settings.").font(.caption).foregroundStyle(.secondary) }`.

`.formStyle(.grouped)`, fixed `.frame(width: 480, height: 260)`, `.accessibilityLabel("Area-to-Clipboard hotkey")` on the Picker.

### `Views/MenuView.swift` (modification)

```swift
Divider()
SettingsLink { Text("Settings…") }
    .keyboardShortcut(",", modifiers: .command)
```

`SettingsLink` (macOS 14+) opens the `Settings { … }` scene from non-app-menu surfaces — works correctly from `MenuBarExtra` despite this being an `LSUIElement` app.

### `ScreenshotButtonApp.swift` (modification)

- New `@State private var hotkeySettings: HotkeySettingsViewModel`.
- `init` constructs `HotkeyMonitor(onFire: { [overlays] in overlays.begin(mode: .area, sink: .toClipboard) })` (strong capture; `overlays` lives the lifetime of the app).
- Existing `.task` on the menu-bar `Image` adds `await hotkeySettings.start()` concurrent with notifier auth + temp pruning via `async let`.
- New scene: `Settings { SettingsView(viewModel: hotkeySettings) }`.

## Data flow

### A. App launch with saved binding (happy path)

```
ScreenshotButtonApp.init
  ├── HotkeyMonitor(onFire: overlays.begin(.area, .toClipboard))
  ├── HotkeySettingsViewModel
  │     └── binding ← decode UserDefaults["areaToClipboardHotkey"]   // e.g. F5
  └── menubar Image .task
        ├── async let auth   = notifier.requestAuthorization()
        ├── async let prune  = TempCleanup.prune(...)
        └── await hotkeySettings.start()
              └── monitor.apply(binding: F5)
                    ├── IOHIDCheckAccess → .granted
                    └── NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                          if event.keyCode == 96 && modifiers empty {
                              onFire()    // → overlays.begin(.area, .toClipboard)
                          }
                      }
              → .applied   (no banner)
```

### B. App launch with saved binding, permission denied

```
hotkeySettings.start()
  └── monitor.apply(binding: F5)
        └── IOHIDCheckAccess → .denied  (or .unknown → IOHIDRequestAccess → still .denied)
              → .permissionDenied
        ↓
  permissionDenied = true                    // observable; SettingsView renders banner
  notifier.postInputMonitoringDenied()       // existing notification path with "Open Settings" action
```

The persisted binding is **kept** — user intent is preserved.

### C. User changes binding in Settings

```
SettingsView Picker  → setBinding(F7)
  HotkeySettingsViewModel.setBinding
    ├── persist(F7)              // encode → UserDefaults
    ├── binding = F7             // observable; Picker reflects
    └── monitor.apply(binding: F7)
          ├── if existing token: NSEvent.removeMonitor(token)
          └── add new global monitor for keyCode 98
          → .applied
  permissionDenied = false       // clears banner if it was showing
```

Picking **None**: same path with `nil` — monitor removed, persisted as `nil`.

If `apply` returns `.permissionDenied`, the persisted binding is *still* the user's choice, the observable `binding` reflects the choice, and the banner appears.

### D. Hotkey fires while another app is frontmost

```
User presses Fn+F5 anywhere on the system
  ↓
WindowServer delivers keyDown(keyCode 96, no modifiers) globally
  ↓
NSEvent global monitor closure fires (on main thread)
  └── event.keyCode == 96 && modifiers empty
        └── onFire()
              └── overlays.begin(mode: .area, sink: .toClipboard)
                    ├── (if a session is already in flight) silent no-op
                    │   per OverlayManager re-entry contract
                    └── otherwise: present per-screen overlay panels →
                        user drags rectangle → commitArea →
                        Capturer → ClipboardSink (NSImage to NSPasteboard) →
                        session .idle
```

### E. Banner → user opens Privacy & Security pane

```
Notification banner ("Open Settings" action)  OR  banner row in SettingsView
  → openInputMonitoringSettings()
      └── NSWorkspace.open(URL("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"))
```

## Permissions

### TCC bucket

**Input Monitoring** — *System Settings → Privacy & Security → Input Monitoring*. Distinct from the Screen Recording bucket the app already uses.

### API

```swift
import IOKit.hid

IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)     // -> .granted | .denied | .unknown (no prompt)
IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)   // -> Bool (synchronously prompts on .unknown)
```

Both are non-deprecated and public. No `Info.plist` usage-description key is required for Input Monitoring — the system supplies the prompt text.

### When the prompt fires

Once, lazily, the first time the user picks a non-None F-key. `HotkeyMonitor.apply` calls `IOHIDRequestAccess` only when transitioning from "no monitor" to "register a monitor." Apps that never enable a hotkey never trigger the prompt — cold-start cost is zero.

### Entitlements

The app is **Developer ID-signed, not sandboxed**. Non-sandboxed apps do not require a `com.apple.security.device.input-monitoring` entitlement. If the project later adopts App Sandbox, that entitlement plus a corresponding profile change would be needed — flagged for `TODO.md` but out of scope today.

### Permission-denied UX

Two surfaces:

1. **Banner row inside `SettingsView`** (primary) — visible whenever the user opens Settings, with an inline "Open Settings" button. The user is right there configuring; this is the discoverable path.
2. **System notification posted on app launch** (secondary) — fires from `start()` when a saved binding can't be applied. Catches the case where the user enabled the hotkey, then revoked permission later, then closed Settings.

### Live revocation

Documented limitation: macOS doesn't notify processes when a TCC permission is revoked. `NSEvent.addGlobalMonitorForEvents` silently stops delivering events. We detect the new state on the next `apply` call. A polling probe is overkill for one hotkey; documented in `TODO.md`.

## Edge cases

| Case | Behavior |
|---|---|
| Modifier held with the F-key (e.g. `Cmd+F5`) | Ignored. v1 binding is strict-no-modifiers. |
| Hotkey pressed while a capture session is already in flight | Silent no-op — `OverlayManager.begin` re-entry contract (existing). |
| Same binding re-applied | `HotkeyMonitor.apply` removes the existing token and re-registers; user-visible behavior identical. |
| Another app has F5 globally bound | Both fire. Cannot be detected with `NSEvent` global monitor. Documented constraint. |
| `UserDefaults` value is malformed JSON | Treated as `nil`. Next `setBinding` overwrites with valid encoding. No crash. |
| First launch, no saved binding | `start()` is a no-op; no permission probe; no prompt. |
| User picks None after using F5 | `apply(nil)` removes the monitor and returns `.applied`. Persisted as `nil`. |
| App quits with monitor registered | `deinit` calls `NSEvent.removeMonitor(token)`. |
| Display layout changes during capture | Out of scope — handled by existing `OverlayManager` per-screen logic. |
| `OverlayManager` mid-construction when hotkey fires | Cannot happen — monitor is registered after `OverlayManager` is instantiated and `start()` runs from `.task` after the menubar Image is on screen. |

### Logging

`os.Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "hotkey")`. Two events:

- `.info` on registration: `"registered hotkey \(label)"`.
- `.info` on fire: `"hotkey fired"`.

No verbose per-keystroke logging — the closure runs on every global keyDown, which is hot.

## Testing

Project standard: Swift Testing (`@Test`, `#expect`), mock at protocol boundaries via init injection, ≥75% coverage. No XCTest.

### `Core/HotkeyBindingTests.swift` (~3 tests)

- `@Test(arguments:)` over `(1, kVK_F1)…(19, kVK_F19)` — validates `init?(fKeyNumber:)` and the derived `label`.
- Out-of-range numbers (`0`, `20`, `-1`, `100`) return `nil`.
- Codable round-trip: encode then decode produces an equal value (covers persistence schema stability).

### `ViewModels/HotkeySettingsViewModelTests.swift` (~7 tests)

Inject `FakeHotkeyMonitor`, ephemeral `UserDefaults(suiteName: UUID().uuidString)`, existing `FakeNotifying`.

- `setBinding(F5)` with `.applied` → `binding == F5`, `permissionDenied == false`, fake monitor's last `apply` is `F5`, `UserDefaults` has the encoded binding.
- `setBinding(F5)` with `.permissionDenied` → `binding == F5` (intent preserved), `permissionDenied == true`, notifier received the denied notification, `UserDefaults` *still* has the binding.
- `setBinding(nil)` after F5 → fake monitor receives `apply(nil)`, `UserDefaults` cleared, `permissionDenied == false`.
- `start()` with no saved binding → fake monitor's `apply` *not* called, no notifier post.
- `start()` with saved binding, granted → `apply` called once with saved value, `permissionDenied == false`.
- `start()` with saved binding, denied → flag set, notifier posts, `binding` still reflects intent.
- Corrupt `UserDefaults` entry → init treats as `nil`, no crash.

### `Fakes/FakeHotkeyMonitor.swift`

```swift
@MainActor
final class FakeHotkeyMonitor: HotkeyMonitoring {
    var nextOutcome: ApplyOutcome = .applied
    private(set) var applyCalls: [HotkeyBinding?] = []
    func apply(binding: HotkeyBinding?) -> ApplyOutcome {
        applyCalls.append(binding); return nextOutcome
    }
}
```

Mirrors the pattern of existing fakes (`FakeSCShareableContent`, `FakePasteboard`, etc.).

### `Notifier` extension

If a `postInputMonitoringDenied()` method is added (or the existing screen-recording denial method is generalized to take a TCC bucket), it gets one new test in `NotifierTests` matching the shape of the existing denial test. Likely the cleanest refactor is a single `postPermissionDenied(kind: .screenRecording | .inputMonitoring)` rather than two parallel methods. Decision deferred to plan-writing time.

### What is not unit-tested

- `HotkeyMonitor` (the live impl). `NSEvent.addGlobalMonitorForEvents` and `IOHIDCheckAccess` need a real WindowServer + a real keyboard event. No XCTest harness reliably injects either.
- `SettingsView` rendering. Manual verification only.

## Manual verification (mandatory pre-merge)

A green test suite is **not** evidence the hotkey works. The plan must include this checklist as a release-blocking acceptance criterion (echoing the cursor-saga lesson):

1. Build & run a Developer ID Debug build per the existing TCC-stable workflow.
2. Open Settings via menu → "Settings…". Confirm the Picker shows F1…F19 + None.
3. Pick **F13** (always-plain F-key, no Fn dance). On first pick, expect the Input Monitoring prompt + System Settings opening Privacy & Security → Input Monitoring. Toggle the app on.
4. Quit the app. Relaunch. Press F13 from inside Chrome (different frontmost app). Expect the per-screen overlay to appear; drag a region; confirm a `.png` lands on the clipboard.
5. Open Settings → Picker → None. Press F13 again. Expect nothing.
6. Re-pick F13. Revoke Input Monitoring permission in System Settings. Press F13. Expect nothing fires (graceful silent fail). Reopen our Settings — banner appears.
7. Re-grant permission. Re-launch. Press F13 — fires again.

Steps 3, 6, and 7 are the ones a CI run can never cover. Spec & plan must list them as required acceptance criteria, not "nice to have."

## Rejected approaches

| Approach | Why rejected |
|---|---|
| **Carbon `RegisterEventHotKey`** | Initial recommendation. User preferred a modern API; the "intercept" property of Carbon stops mattering once the user accepts Fn+F-key as the input gesture (no competing system action to step on). |
| **`NSEvent.addGlobalMonitorForEvents` with intercept-based assumptions** | Discarded an early framing where I incorrectly worried about media-key double-firing. Media-key remapping produces `NSSystemDefined` events, not `keyDown` for the F-key — so a `keyDown` global monitor sees nothing during a media action and there's no double-fire risk. |
| **Submenu inside the existing menu bar dropdown (no Settings window)** | Cheaper to ship but contradicts the user's explicit request for "an options screen opened from the drop down menu" — a window, not an inline submenu. Doesn't scale past one row. |
| **Hotkey recorder UI (any modifier + any key)** | Standard pro-app pattern, but overbuilt for a single-binding v1. `Picker<F1…F19>` matches the user's "function key" framing exactly. |
| **F-key + optional modifiers** | Briefly recommended; rejected by user in favor of plain F-keys with Fn-key handling left to macOS. |
| **`PreferencesStore` protocol around `UserDefaults`** | Rejected on YAGNI grounds. Tests inject `UserDefaults(suiteName: UUID().uuidString)` directly — Apple's documented approach for testing without protocol-wrapping. |
| **Expose all four capture modes in v1** | Rejected by user in favor of A→C only. Persistence is dictionary-typed so adding rows is a UI-only change later. |

## Open questions

None. All scoping decisions made:
- Scope: Area-to-Clipboard only; persistence shape extends.
- Key selection: F1–F19 only, no modifiers.
- Hotkey API: `NSEvent.addGlobalMonitorForEvents`.
- Settings UI: separate `Settings { … }` scene, not a submenu.
- Permission UX: lazy prompt on first non-None pick; banner-in-Settings primary, system notification secondary.
- Persistence: `UserDefaults`, JSON-encoded `HotkeyBinding?`, ephemeral suite for tests.

The single deferred decision (single `postPermissionDenied(kind:)` vs. two parallel methods on `Notifier`) is a refactor question for plan-writing, not a design question.
