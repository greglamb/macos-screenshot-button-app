# Area-to-Clipboard Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: This project's `CLAUDE.md` mandates `superpowers:subagent-driven-development` for execution. **Do NOT use `executing-plans` inline.** Steps use checkbox (`- [ ]`) syntax for tracking. Each task ships in its own commit.

**Goal:** Add a configurable F1–F19 global hotkey for **Area-to-Clipboard** capture, configured from a new Settings window opened from the menu-bar dropdown.

**Architecture:** A new `Core/HotkeyBinding` value type, a `Services/HotkeyMonitoring` protocol with a live `HotkeyMonitor` wrapping `NSEvent.addGlobalMonitorForEvents` (Input Monitoring TCC bucket), an `@Observable` `ViewModels/HotkeySettingsViewModel` persisting to `UserDefaults`, and a SwiftUI `Views/SettingsView`. `Notifying.postPermissionDenied` is generalized to take a `PermissionKind` enum so the existing Screen Recording denial path and the new Input Monitoring denial path share one signature. The hotkey calls the existing `OverlayManager.begin(.area, .toClipboard)` — same entry point the menu uses.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI (`Settings { }` scene, `MenuBarExtra`, `SettingsLink`), AppKit-via-bridging (`NSEvent`, `IOKit.hid`), `UserDefaults` for persistence, Swift Testing for unit tests. No new third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-04-28-area-to-clipboard-hotkey-design.md`

**Non-goals (per spec):** other capture modes' hotkeys, modifier keys, non-F-keys, cross-app collision detection, live revocation detection.

---

## Conventions used in this plan

- **Build & test command (run after every task):**
  ```
  cd .worktrees/area-to-clipboard-hotkey
  xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
    -destination 'platform=macOS,arch=arm64' \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -20
  ```
  Look for `** TEST SUCCEEDED **` (or `** TEST FAILED **`).

- **Project regeneration:** when adding a new Swift source file, the file is automatically picked up because `Project.yml` uses `path: ScreenshotButton` glob includes — no project regeneration required for source additions. Confirm by re-running tests.

- **Commit format:** Conventional Commits, ≤72-char first line. The pre-commit hook will reject otherwise.

- **Frame of reference:** all paths in this plan are relative to the worktree root `.worktrees/area-to-clipboard-hotkey/` (which is the repo root from inside the worktree).

---

## Pre-flight check

Before Task 1, confirm clean baseline. From the worktree:

```
git status                          # → "On branch feature/area-to-clipboard-hotkey, working tree clean"
xcodebuild test ... | tail -5       # → "** TEST SUCCEEDED **", "Test run with 44 tests in 18 suites passed"
```

If either fails, stop and investigate before writing code.

---

## Task 1: `HotkeyBinding` value type

**Files:**
- Create: `ScreenshotButton/Core/HotkeyBinding.swift`
- Test: `ScreenshotButtonTests/Core/HotkeyBindingTests.swift`

- [ ] **Step 1.1: Write the failing tests**

Create `ScreenshotButtonTests/Core/HotkeyBindingTests.swift` with:

```swift
import Foundation
import Testing
import Carbon.HIToolbox    // for kVK_F1...kVK_F19

@testable import ScreenshotButton

@Suite("HotkeyBinding")
struct HotkeyBindingTests {
    @Test("init?(fKeyNumber:) maps 1...19 to the matching kVK_F* keyCode",
          arguments: [
            (1, UInt16(kVK_F1)),  (2, UInt16(kVK_F2)),  (3, UInt16(kVK_F3)),
            (4, UInt16(kVK_F4)),  (5, UInt16(kVK_F5)),  (6, UInt16(kVK_F6)),
            (7, UInt16(kVK_F7)),  (8, UInt16(kVK_F8)),  (9, UInt16(kVK_F9)),
            (10, UInt16(kVK_F10)),(11, UInt16(kVK_F11)),(12, UInt16(kVK_F12)),
            (13, UInt16(kVK_F13)),(14, UInt16(kVK_F14)),(15, UInt16(kVK_F15)),
            (16, UInt16(kVK_F16)),(17, UInt16(kVK_F17)),(18, UInt16(kVK_F18)),
            (19, UInt16(kVK_F19))
          ])
    func mapsFKeyNumberToKeyCode(number: Int, expected: UInt16) {
        let binding = HotkeyBinding(fKeyNumber: number)
        #expect(binding?.keyCode == expected)
        #expect(binding?.label == "F\(number)")
    }

    @Test("init?(fKeyNumber:) returns nil for out-of-range values",
          arguments: [0, -1, 20, 100, Int.max, Int.min])
    func rejectsOutOfRange(number: Int) {
        #expect(HotkeyBinding(fKeyNumber: number) == nil)
    }

    @Test("allFKeys lists F1 through F19 in order")
    func allFKeysIsF1ThroughF19() {
        let labels = HotkeyBinding.allFKeys.map(\.label)
        #expect(labels == (1...19).map { "F\($0)" })
    }

    @Test("Codable round-trip preserves the binding")
    func codableRoundTrip() throws {
        let original = HotkeyBinding(fKeyNumber: 5)!
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 1.2: Run the tests — verify failure**

```
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -30
```

Expected: build failure ("cannot find 'HotkeyBinding' in scope") — that's the test failing because the type doesn't exist.

- [ ] **Step 1.3: Write the minimal implementation**

Create `ScreenshotButton/Core/HotkeyBinding.swift`:

```swift
import Carbon.HIToolbox
import Foundation

struct HotkeyBinding: Sendable, Hashable, Codable {
    let keyCode: UInt16

    var label: String {
        // F1..F19 → derive number from the kVK_F* constants.
        for n in 1...19 {
            if keyCode == HotkeyBinding.keyCode(forFKeyNumber: n) { return "F\(n)" }
        }
        return "?"
    }

    init?(fKeyNumber: Int) {
        guard (1...19).contains(fKeyNumber),
              let code = HotkeyBinding.keyCode(forFKeyNumber: fKeyNumber)
        else { return nil }
        self.keyCode = code
    }

    static let allFKeys: [HotkeyBinding] = (1...19).compactMap(HotkeyBinding.init(fKeyNumber:))

    private static func keyCode(forFKeyNumber n: Int) -> UInt16? {
        switch n {
        case 1:  return UInt16(kVK_F1)
        case 2:  return UInt16(kVK_F2)
        case 3:  return UInt16(kVK_F3)
        case 4:  return UInt16(kVK_F4)
        case 5:  return UInt16(kVK_F5)
        case 6:  return UInt16(kVK_F6)
        case 7:  return UInt16(kVK_F7)
        case 8:  return UInt16(kVK_F8)
        case 9:  return UInt16(kVK_F9)
        case 10: return UInt16(kVK_F10)
        case 11: return UInt16(kVK_F11)
        case 12: return UInt16(kVK_F12)
        case 13: return UInt16(kVK_F13)
        case 14: return UInt16(kVK_F14)
        case 15: return UInt16(kVK_F15)
        case 16: return UInt16(kVK_F16)
        case 17: return UInt16(kVK_F17)
        case 18: return UInt16(kVK_F18)
        case 19: return UInt16(kVK_F19)
        default: return nil
        }
    }
}
```

- [ ] **Step 1.4: Run the tests — verify pass**

Same command as Step 1.2. Expected: `** TEST SUCCEEDED **`, total now 49 tests (44 baseline + 5 new — three parameterized blocks count as one each plus two single tests).

- [ ] **Step 1.5: Commit**

```
git add ScreenshotButton/Core/HotkeyBinding.swift \
        ScreenshotButtonTests/Core/HotkeyBindingTests.swift
git commit -m "feat(core): add HotkeyBinding value type for F1-F19"
```

---

## Task 2: `HotkeyMonitoring` protocol + `ApplyOutcome`

**Files:**
- Create: `ScreenshotButton/Services/HotkeyMonitoring.swift`

This task introduces the protocol seam *without* the live implementation. Pure interface — no behavior to test directly. The fake (Task 3) and the ViewModel (Tasks 5–9) are what depend on this seam.

- [ ] **Step 2.1: Write the file**

Create `ScreenshotButton/Services/HotkeyMonitoring.swift`:

```swift
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
```

- [ ] **Step 2.2: Build to confirm compile**

```
xcodebuild build -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Tests will pass unchanged because nothing references the protocol yet.

- [ ] **Step 2.3: Commit**

```
git add ScreenshotButton/Services/HotkeyMonitoring.swift
git commit -m "feat(services): add HotkeyMonitoring protocol and ApplyOutcome"
```

---

## Task 3: `FakeHotkeyMonitor` test double

**Files:**
- Create: `ScreenshotButtonTests/Fakes/FakeHotkeyMonitor.swift`

- [ ] **Step 3.1: Write the fake**

Create `ScreenshotButtonTests/Fakes/FakeHotkeyMonitor.swift`:

```swift
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
```

- [ ] **Step 3.2: Build to confirm compile**

Same `xcodebuild build` command as Step 2.2. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3.3: Commit**

```
git add ScreenshotButtonTests/Fakes/FakeHotkeyMonitor.swift
git commit -m "test(fakes): add FakeHotkeyMonitor"
```

---

## Task 4: Generalize `Notifying.postPermissionDenied` for two TCC buckets

**Files:**
- Modify: `ScreenshotButton/Services/Notifying.swift`
- Modify: `ScreenshotButton/Services/Notifier.swift`
- Modify: `ScreenshotButton/ViewModels/OverlayManager.swift` (3 call sites)
- Modify: `ScreenshotButtonTests/Fakes/FakeNotifying.swift`
- Modify: `ScreenshotButtonTests/Services/NotifierTests.swift`

The existing `postPermissionDenied()` is hardcoded for Screen Recording. Generalize to take a `PermissionKind` so the new Input Monitoring path can reuse the same shape.

- [ ] **Step 4.1: Update existing test for the new signature, add test for the new path**

Replace `ScreenshotButtonTests/Services/NotifierTests.swift` with:

```swift
import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("Notifier")
struct NotifierTests {
    @Test("Open Settings action routes to the Screen Recording privacy URL")
    func screenRecordingActionRoutes() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: Notifier.openScreenRecordingSettingsAction)

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        #expect(opener.openedURLs == [expected])
    }

    @Test("Open Settings action routes to the Input Monitoring privacy URL")
    func inputMonitoringActionRoutes() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: Notifier.openInputMonitoringSettingsAction)

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        #expect(opener.openedURLs == [expected])
    }

    @Test("Unknown action identifier is a no-op")
    func unknownActionIsNoOp() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: "SOME_OTHER_ACTION")

        #expect(opener.openedURLs.isEmpty)
    }
}
```

- [ ] **Step 4.2: Update `FakeNotifying` to record kind**

Replace `ScreenshotButtonTests/Fakes/FakeNotifying.swift` with:

```swift
import Foundation

@testable import ScreenshotButton

struct RecordedPost: Equatable {
    let title: String
    let body: String
}

@MainActor
final class FakeNotifying: Notifying {
    var posts: [RecordedPost] = []
    var permissionDeniedKinds: [PermissionKind] = []

    func post(title: String, body: String) {
        posts.append(RecordedPost(title: title, body: body))
    }

    func postPermissionDenied(kind: PermissionKind) {
        permissionDeniedKinds.append(kind)
    }
}
```

- [ ] **Step 4.3: Update `Notifying` protocol**

Replace `ScreenshotButton/Services/Notifying.swift` with:

```swift
import Foundation

enum PermissionKind: Sendable, Equatable {
    case screenRecording
    case inputMonitoring
}

@MainActor
protocol Notifying {
    func post(title: String, body: String)
    func postPermissionDenied(kind: PermissionKind)
}
```

- [ ] **Step 4.4: Update `Notifier` impl**

Replace `ScreenshotButton/Services/Notifier.swift` with:

```swift
import Foundation
import UserNotifications

@MainActor
final class Notifier: NSObject, Notifying {
    private var didRequestAuth = false
    private let opener: any URLOpening

    nonisolated static let openScreenRecordingSettingsAction = "OPEN_SCREEN_RECORDING_SETTINGS"
    nonisolated static let openInputMonitoringSettingsAction = "OPEN_INPUT_MONITORING_SETTINGS"
    nonisolated static let screenRecordingCategory = "PERMISSION_DENIED_SCREEN_RECORDING"
    nonisolated static let inputMonitoringCategory = "PERMISSION_DENIED_INPUT_MONITORING"
    nonisolated static let plainCategory = "PLAIN"

    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!
    static let inputMonitoringSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!

    init(opener: any URLOpening = SystemURLOpener()) {
        self.opener = opener
        super.init()
        let openScreenRecording = UNNotificationAction(
            identifier: Self.openScreenRecordingSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let openInputMonitoring = UNNotificationAction(
            identifier: Self.openInputMonitoringSettingsAction,
            title: "Open Settings",
            options: [.foreground]
        )
        let screenRecording = UNNotificationCategory(
            identifier: Self.screenRecordingCategory,
            actions: [openScreenRecording],
            intentIdentifiers: [],
            options: []
        )
        let inputMonitoring = UNNotificationCategory(
            identifier: Self.inputMonitoringCategory,
            actions: [openInputMonitoring],
            intentIdentifiers: [],
            options: []
        )
        let plain = UNNotificationCategory(
            identifier: Self.plainCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories(
            [screenRecording, inputMonitoring, plain]
        )
        UNUserNotificationCenter.current().delegate = self
    }

    func post(title: String, body: String) {
        Task { [weak self] in
            await self?.requestAuthorization()
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = Self.plainCategory
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    func postPermissionDenied(kind: PermissionKind) {
        Task { [weak self] in
            await self?.requestAuthorization()
            let content = UNMutableNotificationContent()
            switch kind {
            case .screenRecording:
                content.title = "Screen Recording permission required"
                content.body = "ScreenshotButton needs Screen Recording access in System Settings to capture windows and regions."
                content.categoryIdentifier = Self.screenRecordingCategory
            case .inputMonitoring:
                content.title = "Input Monitoring permission required"
                content.body = "ScreenshotButton needs Input Monitoring access in System Settings to receive global hotkeys."
                content.categoryIdentifier = Self.inputMonitoringCategory
            }
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(req)
        }
    }

    func requestAuthorization() async {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func handle(actionIdentifier: String) async {
        switch actionIdentifier {
        case Self.openScreenRecordingSettingsAction:
            opener.open(Self.screenRecordingSettingsURL)
        case Self.openInputMonitoringSettingsAction:
            opener.open(Self.inputMonitoringSettingsURL)
        default:
            break
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handle(actionIdentifier: response.actionIdentifier)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

Note: the old constant name `openSettingsAction` is renamed to `openScreenRecordingSettingsAction`. If any code outside what's enumerated above references it, search and update.

- [ ] **Step 4.5: Update OverlayManager call sites**

In `ScreenshotButton/ViewModels/OverlayManager.swift`, find all 3 occurrences of `notifier.postPermissionDenied()` (or `.postPermissionDenied()`). Replace each with `.postPermissionDenied(kind: .screenRecording)`. Specifically:

- The closure passed into `controller.enumerateWindowsOrHandle(notifier: notifier)` — the line currently `notifier.postPermissionDenied()` becomes `notifier.postPermissionDenied(kind: .screenRecording)`.
- In `didClickWindow`, the `case .userDeclined` branch — `self.notifier.postPermissionDenied()` becomes `self.notifier.postPermissionDenied(kind: .screenRecording)`.
- In `didCompleteArea`, the `case .userDeclined` branch — same change.

- [ ] **Step 4.6: Run the tests — verify all pass**

```
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`. Test count rises by 1 (the new Input Monitoring action test). If anything fails, it's a missed call site — search the codebase: `grep -r "postPermissionDenied(" ScreenshotButton ScreenshotButtonTests`.

- [ ] **Step 4.7: Commit**

```
git add ScreenshotButton/Services/Notifying.swift \
        ScreenshotButton/Services/Notifier.swift \
        ScreenshotButton/ViewModels/OverlayManager.swift \
        ScreenshotButtonTests/Fakes/FakeNotifying.swift \
        ScreenshotButtonTests/Services/NotifierTests.swift
git commit -m "refactor(notifier): generalize postPermissionDenied to take kind"
```

---

## Task 5: `HotkeySettingsViewModel` — load from UserDefaults

**Files:**
- Create: `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`
- Test: `ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift`

The full test file accumulates over Tasks 5–8. This task introduces it with just the load-related tests.

- [ ] **Step 5.1: Write the failing tests**

Create `ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift`:

```swift
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
```

- [ ] **Step 5.2: Run the tests — verify failure**

```
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: build failure ("cannot find 'HotkeySettingsViewModel' in scope").

- [ ] **Step 5.3: Write the minimal implementation**

Create `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
@MainActor
final class HotkeySettingsViewModel {
    static let defaultsKey = "areaToClipboardHotkey"

    private(set) var binding: HotkeyBinding?
    private(set) var permissionDenied: Bool = false

    private let monitor: any HotkeyMonitoring
    private let defaults: UserDefaults
    private let opener: any URLOpening
    private let notifier: any Notifying

    init(monitor: any HotkeyMonitoring,
         defaults: UserDefaults,
         opener: any URLOpening,
         notifier: any Notifying) {
        self.monitor = monitor
        self.defaults = defaults
        self.opener = opener
        self.notifier = notifier
        self.binding = Self.load(from: defaults)
    }

    private static func load(from defaults: UserDefaults) -> HotkeyBinding? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }
}
```

- [ ] **Step 5.4: Run the tests — verify pass**

Same xcodebuild command. Expected: `** TEST SUCCEEDED **`, 3 new tests passing.

- [ ] **Step 5.5: Commit**

```
git add ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift \
        ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift
git commit -m "feat(viewmodels): HotkeySettingsViewModel loads binding from UserDefaults"
```

---

## Task 6: `HotkeySettingsViewModel.setBinding` — applied + denied paths

**Files:**
- Modify: `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`
- Modify: `ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift`

- [ ] **Step 6.1: Add the failing tests**

Append inside the `HotkeySettingsViewModelTests` struct, before the closing `}`:

```swift
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
```

- [ ] **Step 6.2: Run the tests — verify failure**

Expected: build failure ("HotkeySettingsViewModel has no member 'setBinding'").

- [ ] **Step 6.3: Add `setBinding` to the ViewModel**

In `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`, add this method inside the class (before the closing `}`):

```swift
    func setBinding(_ new: HotkeyBinding?) {
        persist(new)
        binding = new

        let outcome = monitor.apply(binding: new)
        switch outcome {
        case .applied:
            permissionDenied = false
        case .permissionDenied:
            permissionDenied = true
            notifier.postPermissionDenied(kind: .inputMonitoring)
        }
    }

    private func persist(_ value: HotkeyBinding?) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }
```

- [ ] **Step 6.4: Run the tests — verify pass**

Same xcodebuild command. Expected: 4 new tests passing.

- [ ] **Step 6.5: Commit**

```
git add ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift \
        ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift
git commit -m "feat(viewmodels): setBinding persists, applies, posts banner on deny"
```

---

## Task 7: `HotkeySettingsViewModel.start()` — apply on launch

**Files:**
- Modify: `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`
- Modify: `ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift`

- [ ] **Step 7.1: Add the failing tests**

Append inside the `HotkeySettingsViewModelTests` struct:

```swift
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
```

- [ ] **Step 7.2: Run the tests — verify failure**

Expected: build failure on `vm.start()` — method doesn't exist yet.

- [ ] **Step 7.3: Add `start()` to the ViewModel**

In `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`, add inside the class:

```swift
    /// Apply the persisted binding (if any) to the live monitor. Call once at app launch.
    /// No-op when no binding is saved — avoids the Input Monitoring permission probe entirely.
    func start() async {
        guard let binding else { return }
        let outcome = monitor.apply(binding: binding)
        switch outcome {
        case .applied:
            permissionDenied = false
        case .permissionDenied:
            permissionDenied = true
            notifier.postPermissionDenied(kind: .inputMonitoring)
        }
    }
```

- [ ] **Step 7.4: Run the tests — verify pass**

Same xcodebuild. Expected: 3 new tests passing.

- [ ] **Step 7.5: Commit**

```
git add ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift \
        ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift
git commit -m "feat(viewmodels): start() applies saved binding, surfaces denial"
```

---

## Task 8: `HotkeySettingsViewModel.openInputMonitoringSettings`

**Files:**
- Modify: `ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift`
- Modify: `ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift`

- [ ] **Step 8.1: Add the failing test**

Append inside `HotkeySettingsViewModelTests`:

```swift
    @Test("openInputMonitoringSettings opens the Input Monitoring privacy URL")
    func openSettingsRoutesToCorrectURL() {
        let opener = FakeURLOpener()
        let vm = HotkeySettingsViewModel(
            monitor: FakeHotkeyMonitor(),
            defaults: Self.ephemeralDefaults(),
            opener: opener,
            notifier: FakeNotifying()
        )

        vm.openInputMonitoringSettings()

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        #expect(opener.openedURLs == [expected])
    }
```

- [ ] **Step 8.2: Run the tests — verify failure**

Expected: build failure on missing method.

- [ ] **Step 8.3: Add `openInputMonitoringSettings` to the ViewModel**

In `HotkeySettingsViewModel.swift`, add:

```swift
    func openInputMonitoringSettings() {
        opener.open(Notifier.inputMonitoringSettingsURL)
    }
```

(Reusing the `Notifier.inputMonitoringSettingsURL` constant added in Task 4 — single source of truth.)

- [ ] **Step 8.4: Run the tests — verify pass**

- [ ] **Step 8.5: Commit**

```
git add ScreenshotButton/ViewModels/HotkeySettingsViewModel.swift \
        ScreenshotButtonTests/ViewModels/HotkeySettingsViewModelTests.swift
git commit -m "feat(viewmodels): openInputMonitoringSettings routes via URLOpening"
```

---

## Task 9: `HotkeyMonitor` live implementation (no unit test)

**Files:**
- Create: `ScreenshotButton/Services/HotkeyMonitor.swift`

This is the live `NSEvent` + `IOHID` impl. Per the spec, **end-to-end behavior is not unit-testable** (no real WindowServer in test, no real keyboard). Coverage = compile + manual verification (Task 13).

- [ ] **Step 9.1: Write the implementation**

Create `ScreenshotButton/Services/HotkeyMonitor.swift`:

```swift
import AppKit
import IOKit.hid
import os

private let hotkeyLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "hotkey")

@MainActor
final class HotkeyMonitor: HotkeyMonitoring {
    private var token: Any?
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
```

Note on the `Task { @MainActor }` hop: Apple's documentation for `addGlobalMonitorForEvents` does not guarantee main-thread delivery. The hop ensures `onFire` always runs on the main actor, satisfying Swift 6 strict concurrency without us depending on undocumented behavior.

- [ ] **Step 9.2: Build to verify it compiles**

```
xcodebuild build -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Tests still pass — this file is unreferenced until Task 11.

- [ ] **Step 9.3: Commit**

```
git add ScreenshotButton/Services/HotkeyMonitor.swift
git commit -m "feat(services): HotkeyMonitor wraps NSEvent + IOHID Input Monitoring"
```

---

## Task 10: `SettingsView`

**Files:**
- Create: `ScreenshotButton/Views/SettingsView.swift`

No unit tests — SwiftUI view. Coverage = visual verification in Task 13.

- [ ] **Step 10.1: Write the view**

Create `ScreenshotButton/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: HotkeySettingsViewModel

    var body: some View {
        Form {
            Section("Capture Hotkeys") {
                Picker("Area to Clipboard", selection: bindingForPicker) {
                    Text("None").tag(HotkeyBinding?.none)
                    ForEach(HotkeyBinding.allFKeys, id: \.self) { key in
                        Text(key.label).tag(HotkeyBinding?.some(key))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Area-to-Clipboard hotkey")

                if viewModel.permissionDenied {
                    LabeledContent {
                        Button("Open Settings") {
                            viewModel.openInputMonitoringSettings()
                        }
                    } label: {
                        Text("Input Monitoring is required for global hotkeys.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text("Tip: macOS may map F1–F12 to media keys. Hold Fn or enable F-keys-as-standard-keys in System Settings → Keyboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
    }

    private var bindingForPicker: Binding<HotkeyBinding?> {
        Binding(
            get: { viewModel.binding },
            set: { viewModel.setBinding($0) }
        )
    }
}
```

- [ ] **Step 10.2: Build to verify it compiles**

Same `xcodebuild build` command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10.3: Commit**

```
git add ScreenshotButton/Views/SettingsView.swift
git commit -m "feat(views): SettingsView with F-key Picker and denial banner"
```

---

## Task 11: Wire Settings scene + menu entry into the app

**Files:**
- Modify: `ScreenshotButton/Views/MenuView.swift`
- Modify: `ScreenshotButton/ScreenshotButtonApp.swift`

This is where `HotkeyMonitor` and `HotkeySettingsViewModel` are first instantiated and the `Settings { }` scene is added.

- [ ] **Step 11.1: Update `MenuView` to include a Settings link**

In `ScreenshotButton/Views/MenuView.swift`, find the section ending with the Quit item:

```swift
        Divider()
        Button("Quit ScreenshotButton") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
```

Insert before the existing `Divider()` immediately above this Button:

```swift
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)
```

So the relevant tail of `MenuView.body` becomes:

```swift
        Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
            .onChange(of: launchAtLoginEnabled) { _, newValue in
                let handler = AutolaunchToggleHandler(launchAtLogin: launchAtLogin, notifier: notifier)
                launchAtLoginEnabled = handler.setEnabled(newValue)
            }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit ScreenshotButton") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
        Divider()
        Text("Version \(Self.versionString)")
            .font(.caption)
            .foregroundStyle(.secondary)
```

- [ ] **Step 11.2: Update `ScreenshotButtonApp` to instantiate the monitor + add the Settings scene**

Replace `ScreenshotButton/ScreenshotButtonApp.swift` with:

```swift
import SwiftUI

@main
struct ScreenshotButtonApp: App {
    @State private var controller: CaptureController
    @State private var overlays: OverlayManager
    @State private var hotkeySettings: HotkeySettingsViewModel
    private let launchAtLogin = LaunchAtLogin()
    private let notifier = Notifier()

    init() {
        let controller = CaptureController.live()
        let overlays = OverlayManager(controller: controller, notifier: notifier)
        let hotkey = HotkeyMonitor { [overlays] in
            overlays.begin(mode: .area, sink: .toClipboard)
        }
        let settings = HotkeySettingsViewModel(
            monitor: hotkey,
            defaults: .standard,
            opener: SystemURLOpener(),
            notifier: notifier
        )
        _controller = State(initialValue: controller)
        _overlays = State(initialValue: overlays)
        _hotkeySettings = State(initialValue: settings)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(launchAtLogin: launchAtLogin, notifier: notifier) { mode, sink in
                overlays.begin(mode: mode, sink: sink)
            }
        } label: {
            Image(systemName: "camera.metering.center.weighted")
                .accessibilityLabel("ScreenshotButton")
                .task(priority: .background) {
                    // Fire auth, temp cleanup, and hotkey-monitor application concurrently:
                    // a stalled permission prompt must not delay any of them.
                    async let auth: Void = notifier.requestAuthorization()
                    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(FileSink.folderName, isDirectory: true)
                    TempCleanup.prune(directory: dir, olderThan: 60 * 60 * 24)
                    await hotkeySettings.start()
                    _ = await auth
                }
        }

        Settings {
            SettingsView(viewModel: hotkeySettings)
        }
    }
}

extension CaptureController {
    @MainActor
    static func live() -> CaptureController {
        CaptureController(
            enumerator: WindowEnumerator(),
            capturer: Capturer(manager: SCScreenshotManagerAdapter()),
            fileSink: FileSink(),
            clipboardSink: ClipboardSink()
        )
    }
}
```

Notes:
- The closure passed to `HotkeyMonitor` strong-captures `overlays`. This is intentional — `overlays` lives the entire app lifetime, no cycle exists (HotkeyMonitor doesn't reference itself through OverlayManager), and weak capture would force optional-chaining for no benefit.
- `hotkeySettings.start()` is awaited *before* `auth` to avoid showing two TCC prompts simultaneously (Notifications + Input Monitoring) on a fresh install with a saved binding. In practice the order rarely matters because (a) most users land on a fresh install with no saved binding, in which case `start()` is a no-op, and (b) the auth Task is structured concurrent and not blocking. If the prompt-stacking concern turns out unfounded in real testing, change to `async let start = ...` + `_ = await (auth, start)` for full concurrency.

- [ ] **Step 11.3: Build & run all tests**

```
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -10
```

Expected: `** TEST SUCCEEDED **`. No new tests in this task; existing tests continue to pass.

- [ ] **Step 11.4: Commit**

```
git add ScreenshotButton/Views/MenuView.swift \
        ScreenshotButton/ScreenshotButtonApp.swift
git commit -m "feat(app): Settings scene with Area-to-Clipboard hotkey wiring"
```

---

## Task 12: Documentation — CHANGELOG, TODO, ARCHITECTURE

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `TODO.md`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 12.1: Update `CHANGELOG.md`**

Under `## [Unreleased] → ### Added`, insert this bullet (above any existing entries in that subsection — there should be none, since v0.0.7 was just released):

```markdown
- **Configurable global hotkey for Area-to-Clipboard.** A new "Settings…" entry in the menu-bar dropdown opens a Settings window with an F1–F19 picker. Pressing the chosen function key from any frontmost app starts the area-selection overlay and copies the result to the clipboard. Requires a one-time *Input Monitoring* permission grant in System Settings → Privacy & Security on first use; macOS prompts on first selection. Plain F-keys only in v1 (no modifiers); on Macs configured with F1–F12 as media keys, hold **Fn** or enable *"Use F-keys as standard function keys"* in System Settings → Keyboard.
```

- [ ] **Step 12.2: Update `TODO.md` known limitations**

Under `## Known limitations`, append:

```markdown
- **Live revocation of Input Monitoring permission is not detected.** macOS does not notify processes when a TCC permission is revoked while the app is running. The hotkey silently stops firing; the in-Settings banner only updates on the next binding change or app relaunch. A polling probe would be overkill for one hotkey.
- **Cross-app hotkey collisions are not detected.** `NSEvent.addGlobalMonitorForEvents` is observe-only — if another app has bound the same key globally, both fire on the same keystroke. Documented constraint of the chosen API; would require Carbon `RegisterEventHotKey` to detect.
- **App Sandbox not adopted.** If sandbox is later required (e.g. for App Store distribution), the new hotkey feature will need the `com.apple.security.device.input-monitoring` entitlement and a corresponding provisioning profile change.
```

Under `## Deferred from v1`, update the Global hotkeys entry — find:

```markdown
- **Global hotkeys** for the four capture modes — scope-cut to keep v1 menu-only. ...
```

and append after that line:

```markdown
- **Global hotkeys for the remaining three modes** (Window-to-File, Area-to-File, Window-to-Clipboard) — A→C ships in v0.0.8; persistence is dictionary-typed so adding rows to `SettingsView` is a UI-only change.
```

- [ ] **Step 12.3: Update `docs/ARCHITECTURE.md`**

In the `## Module layout` block, in the `Services/` line list, append `, HotkeyMonitor` to the existing services enumeration. In the `ViewModels/` line, append `, HotkeySettingsViewModel`. In the `Views/` line, append `, SettingsView`.

In the `## Data flow` section, after the existing menu-click flow, append a new flow:

```
Hotkey press (anywhere on system, F-key alone, no modifiers)
            →  NSEvent global monitor fires (HotkeyMonitor)
            →  onFire callback (configured in ScreenshotButtonApp.init)
            →  OverlayManager.begin(mode: .area, sink: .toClipboard)
            →  (same downstream flow as menu click)
```

- [ ] **Step 12.4: Commit**

```
git add CHANGELOG.md TODO.md docs/ARCHITECTURE.md
git commit -m "docs: changelog/TODO/architecture for area-to-clipboard hotkey"
```

---

## Task 13: Manual verification (release-blocking, per spec)

**Files:** none (verification only)

This is the cursor-saga lesson. A green test suite is **not** evidence the hotkey works. None of these steps can be automated in CI.

Build a local Developer-ID-signed Debug build using the project's TCC-stable workflow (avoids auth-loop bugs from re-signing). The exact incantation is documented in `_gitignored/conventions/tcc-auth-loop-prevention.md` if present locally; the basic shape is:

```
xcodebuild -project ScreenshotButton.xcodeproj -scheme ScreenshotButton \
  -configuration Debug -derivedDataPath build_debug build
ditto build_debug/Build/Products/Debug/ScreenshotButton.app build_debug_launch/ScreenshotButton.app
rm -rf build_debug
open -n build_debug_launch/ScreenshotButton.app
```

If you don't have local conventions for this, ask the user to do the build + launch interactively rather than guessing — mis-signed Debug builds break TCC permission persistence.

- [ ] **Step 13.1: Open Settings**

From the menu-bar icon, click **Settings…**. Confirm:
- [ ] Settings window opens.
- [ ] A `Form` with one section labeled "Capture Hotkeys".
- [ ] A "Area to Clipboard" Picker showing "None" by default.
- [ ] Picker contents: None, F1, F2, …, F19 in order.
- [ ] No banner is visible (no permission state to surface).
- [ ] The Fn-tip caption is shown below.

- [ ] **Step 13.2: First grant — pick F13**

Pick **F13** (always-plain function key — won't compete with media-key behavior).

Expected:
- [ ] macOS shows the Input Monitoring permission prompt.
- [ ] System Settings opens to *Privacy & Security → Input Monitoring*. (If it doesn't open automatically: open it manually.)
- [ ] Toggle ScreenshotButton **on** in the Input Monitoring list. macOS may relaunch the app or ask you to confirm; restart from the menu bar if the app dies.

- [ ] **Step 13.3: Hotkey fires from another app**

After re-granting and relaunching:
- [ ] Bring **Chrome** (or any non-ScreenshotButton app) to the front.
- [ ] Press **F13**.
- [ ] Per-screen overlay appears, drag a small rectangle.
- [ ] Open Preview's "New from Clipboard" (or any clipboard-paste UI). Confirm the captured PNG is on the clipboard.

- [ ] **Step 13.4: Disable hotkey**

In the app's Settings window:
- [ ] Pick **None** in the Picker.
- [ ] Press F13 from another app.
- [ ] Nothing happens (no overlay, no clipboard mutation).

- [ ] **Step 13.5: Revoke permission while running**

- [ ] Re-pick F13 in Settings.
- [ ] Open System Settings → Privacy & Security → Input Monitoring.
- [ ] Toggle ScreenshotButton **off**.
- [ ] Press F13. Nothing fires (graceful silent fail).
- [ ] Re-open the app's Settings — confirm the "Input Monitoring is required" banner is visible *if* the user re-enters Settings or re-applies a binding (per spec, live revocation isn't auto-detected; this is documented).

- [ ] **Step 13.6: Re-grant + re-launch**

- [ ] In System Settings, toggle ScreenshotButton's Input Monitoring back on.
- [ ] Relaunch the app from the menu bar.
- [ ] Press F13. Hotkey fires; overlay + clipboard work as in Step 13.3.

- [ ] **Step 13.7: Persistence across launches**

- [ ] Quit the app.
- [ ] Relaunch.
- [ ] Confirm the Picker shows F13 (binding persisted via UserDefaults).
- [ ] Press F13. Hotkey fires.

- [ ] **Step 13.8: Modifier-held does nothing**

- [ ] In another app, press **Cmd-F13**. Nothing fires (strict no-modifiers binding).

- [ ] **Step 13.9: Visual verification of menu copy**

- [ ] In the menu bar dropdown, the entry reads "Settings…" with a `⌘,` shortcut hint visible.

If any step fails, **do not** declare the task complete — debug, fix, write a failing test that captures the bug if possible, and re-run. The cursor saga from 2026-04-19/20 is exactly the failure mode this checklist exists to prevent.

- [ ] **Step 13.10: Document the verification result**

Once all steps above pass, append a short verification note to the spec or this plan (e.g., a comment at the bottom of the plan with the date and tester):

> Manual verification 2026-MM-DD by <tester>: All 9 sub-steps passed on macOS X.Y.

Commit with:

```
git add docs/superpowers/plans/2026-04-28-area-to-clipboard-hotkey-implementation.md
git commit -m "docs: record manual verification of area-to-clipboard hotkey"
```

---

## Self-review (already performed)

**Spec coverage:**
- §Architecture file layout → Tasks 1, 2, 3, 5–9, 10, 11. ✓
- §Components shapes → Task 1 (HotkeyBinding), Task 2 (protocol), Task 9 (HotkeyMonitor), Tasks 5–8 (ViewModel), Task 10 (SettingsView), Task 11 (App + MenuView). ✓
- §Data flow A (launch + happy path) → Tasks 7 (start) + 11 (App.task). ✓
- §Data flow B (launch + denied) → Task 7 test "startWithDeniedPostsBanner". ✓
- §Data flow C (user changes binding) → Task 6 tests. ✓
- §Data flow D (hotkey fires) → Task 9 (live impl, manual verify in Task 13). ✓
- §Data flow E (banner → settings) → Task 8. ✓
- §Permissions (TCC bucket, API, prompt timing, deep link) → Task 9 (HotkeyMonitor) + Task 4 (URL constant) + Task 8 (open). ✓
- §Edge cases (modifier ignored, re-entry, malformed defaults, first launch, etc.) → Task 9 closure logic; Task 5 corrupt-defaults test; OverlayManager re-entry is existing behavior. ✓
- §Logging → Task 9 emits `.info` on registration + fire. ✓
- §Testing strategy → Tasks 1, 4, 5–8 cover the listed test files. FakeHotkeyMonitor is Task 3. ✓
- §Manual verification (mandatory pre-merge) → Task 13. ✓
- §Rejected approaches → already in TODO.md and spec. ✓

**Placeholder scan:** Searched for "TBD", "TODO", "etc.", "similar to" — none found in the task bodies. The "If signing config differs" line in Task 13's intro is a contingency, not a placeholder.

**Type consistency:** `HotkeyBinding`, `HotkeyMonitoring`, `ApplyOutcome`, `HotkeySettingsViewModel`, `HotkeyMonitor`, `PermissionKind`, `Notifier.openInputMonitoringSettingsAction`, `Notifier.inputMonitoringSettingsURL`, `HotkeySettingsViewModel.defaultsKey` — all referenced consistently across tasks. `setBinding(_:)` signature matches every test and call site. `start()` is `async` and returns Void everywhere.

---

## Execution handoff

Per `CLAUDE.md` execution preferences for this project:
- **Use `superpowers:subagent-driven-development`** to execute this plan task-by-task.
- **Do not** use `executing-plans` inline (CLAUDE.md: "Always use subagent-driven development. Never use batch execution. Never ask which mode to use.").
- Each task gets a fresh subagent + two-stage review (spec compliance, then code quality).
- After all tasks pass review, use `superpowers:finishing-a-development-branch` for the merge/PR/discard decision.
