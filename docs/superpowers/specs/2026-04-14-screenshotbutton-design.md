# ScreenshotButton — Design Spec

**Date:** 2026-04-14
**Status:** Approved, ready for implementation plan
**Author:** Greg Lamb (with Claude)

## Summary

A macOS 14+ menu-bar utility that captures windows or drawn rectangles to either a PNG file (opened in Preview) or the system clipboard. Distributed via a Homebrew cask hosted in this repo, signed and notarized per the house conventions in `_gitignored/macos-app-release-conventions.md`.

## Product scope

### Menu

A `MenuBarExtra` with a `viewfinder` SF Symbol icon and six items, matching the reference screenshot the user supplied (the reference shows a camera glyph for layout purposes; the shipped icon is `viewfinder` for clearer screenshot semantics):

1. Window to File
2. Area to File
3. Window to Clipboard
4. Area to Clipboard
5. Autolaunch (toggle)
6. Quit ScreenshotButton

### Behavior per capture mode

- **Window to File / Window to Clipboard.** Selecting the item enters a modal capture session. Moving the cursor over any window highlights it with a 2pt accent stroke and subtle fill. Clicking a highlighted window captures it. Capture works even when the target window is obscured or partially off-screen — `ScreenCaptureKit` returns the window's pixels independently of z-order and clipping.
- **Area to File / Area to Clipboard.** Modal capture session with a crosshair cursor. Drag to draw a rectangle; `mouseUp` commits. Drag size < 5pt² is treated as an accidental click and cancels the session.
- **Space** during any capture session toggles between window and area mode. No on-screen label — the cursor change and highlight behavior are the signal.
- **Esc** during a capture session cancels without capturing.
- **Click on empty space in window mode** cancels the session (matches macOS `Cmd-Shift-4-Space`).

### File vs. clipboard delivery

- **File modes.** Write PNG to `NSTemporaryDirectory()/ScreenshotButton/ScreenshotButton-YYYY-MM-DD-HH-mm-ss.png`, then `NSWorkspace.shared.open(...)` on Preview.app. The user saves from Preview.
- **Clipboard modes.** Copy to `NSPasteboard.general` as `NSImage`, so any target app can request its preferred representation (PDF, TIFF, raw PNG bytes).

### Autolaunch

A `Toggle` bound to a `LaunchAtLogin` wrapper around `SMAppService.mainApp`. State mirrored into `UserDefaults` so the menu shows correct initial state on relaunch.

### Out of scope for v1

- Global hotkeys (keep v1 tight; no recorder UI, no collision detection)
- Settings window (save location is fixed; launch-at-login lives in the menu itself)
- Sparkle auto-updates (brew handles updates)
- Drop shadows on captured windows (dropped from scope — removes `ShadowCompositor` entirely)
- Cursor inclusion in captures (matches macOS default)
- Annotation/markup (Preview handles it for file mode)
- Sandboxing (screen-recording apps live outside the sandbox; brew cask friendly)

## Architecture

### Layering

```
┌────────────────────────────────────────────────────────────┐
│ SwiftUI layer                                              │
│   ScreenshotButtonApp (App)                                │
│     └─ MenuBarExtra → MenuView                             │
│                                                            │
│ Coordinator (@Observable, @MainActor)                      │
│   AppState          – current session, autolaunch flag     │
│   CaptureController – starts/ends sessions, routes mode    │
│                                                            │
│ Capture services (actors / value types)                    │
│   WindowEnumerator  – SCShareableContent → [CapturedWindow]│
│   Capturer          – SCScreenshotManager → CGImage        │
│   Sink              – .toFile | .toClipboard               │
│   LaunchAtLogin     – SMAppService wrapper                 │
│                                                            │
│ AppKit overlay (one per NSScreen)                          │
│   OverlayPanel (NSPanel) → OverlayView (NSView)            │
│     – window highlight, rubber-band rectangle,             │
│       keyDown (Esc/Space), mouseUp                         │
└────────────────────────────────────────────────────────────┘
```

### Framework choice rationale

- **MenuBarExtra + AppKit overlay.** SwiftUI on macOS 14 cannot cleanly produce a per-screen borderless `NSPanel`-equivalent window with raw `NSEvent` routing. AppKit owns only what SwiftUI can't do well. Everything else (menu, future Settings) is SwiftUI-native. Chosen over all-AppKit (too much boilerplate, no `@Observable`) and all-SwiftUI (bad fit for the overlay).
- **ScreenCaptureKit.** Required for isolated window capture even when obscured or off-screen. Successor to deprecated `CGWindowListCreateImage`.
- **`SMAppService.mainApp`.** Modern macOS 13+ launch-at-login API. No helper bundle required.
- **`@Observable` coordinator.** Ensures overlays across multiple displays stay synchronized on mode and hover state through a single source of truth.

### Capture-session state machine

```
    ┌─────────┐   menu click
    │  Idle   │─────────────────────►┐
    └─────────┘                      │
         ▲                           ▼
         │                    ┌─────────────┐
         │   Esc / done /     │ Capturing   │  space
         │   click outside    │  · Window   │◄────────┐
         │                    │  · Area     │─────────┘
         │                    └─────────────┘
         │                           │
         │            click / drag-release
         │                           ▼
         │                    ┌─────────────┐
         └────────────────────│  Delivering │
                              │ (capture →  │
                              │  sink)      │
                              └─────────────┘
```

- **Idle** is the only state in which the menu accepts commands. Re-entering via the menu while in `Capturing` is a no-op (the menu is closed by the capture session grabbing focus anyway, but defensive idempotency kills a class of bugs).
- **Capturing** owns the overlay panels and tracks `mode: .window | .area` plus `hoveredWindow: SCWindow?`.
- **Delivering** is async (SCK call + sink write) and *non-cancellable*. Esc no longer cancels once the click has committed — otherwise the UX is "where did my screenshot go?".

### Overlay behavior (per `NSScreen`)

- Borderless `NSPanel` at `.screenSaver + 1`, `backgroundColor = .clear`, accepts first responder.
- One panel per screen, all sharing a `CaptureSession` reference so mode changes and hover updates propagate across displays.
- **Window mode:** hit-test against `SCShareableContent` snapshot, highlight the topmost window at cursor. Only one highlight at a time across all screens.
- **Area mode:** overlay under the cursor shows crosshair + rubber-band rectangle; others show nothing.
- **Drag:** `mouseDown` starts, `mouseDragged` updates, `mouseUp` commits. Size < 5pt² cancels.
- **Keys:** `keyDown` handler on the panel routes `.escape` (cancel) and `.space` (toggle mode). Other keys are passed through.

### Multi-display

`SCShareableContent` enumerates windows across all displays with global coordinates. Window-mode hit-testing uses global coordinates so a window that spans two displays is highlighted consistently. Area-mode capture uses the local screen's `SCContentFilter` cropped to the drag rectangle in display-local coordinates.

## Data flow

```
CaptureSession.result
        │
        ▼
  Capturer.capture(target) ──► CGImage
        │
        ▼
  Sink.deliver(image, mode)
     │
     ├─ .toFile        → write temp PNG → NSWorkspace.open(url) with Preview
     └─ .toClipboard   → NSPasteboard.general.writeObjects([NSImage])
```

### Capture targets

| Mode | `SCScreenshotManager` input |
|------|----------------------------|
| Window | `SCContentFilter(desktopIndependentWindow: scWindow)` — pixels of just that window |
| Area   | `SCContentFilter(display: scDisplay, excludingWindows: [])` then crop to drag rect |

Both produce a `CGImage` preserving Retina pixel density.

### File sink details

- Filename: `ScreenshotButton-YYYY-MM-DD-HH-mm-ss.png`, folder: `NSTemporaryDirectory()/ScreenshotButton/`.
- Encoder: `CGImageDestinationCreateWithURL(..., kUTTypePNG, 1, nil)` with `kCGImagePropertyDPIWidth/Height = 144`.
- Preview invocation: `NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Preview.app"), configuration: .init())`.
- Cleanup: on app launch, delete files in the temp folder older than 24h. Don't delete on Preview-close — Preview reads lazily and closing the file breaks Save As.

### Clipboard sink details

`NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([NSImage(cgImage: cg, size: .init(width: cg.width, height: cg.height))])`. Targets like Slack/Messages/Pages ask the pasteboard for the representation they want.

## Permissions, errors, and logging

### TCC — Screen Recording

- **No pre-prompt.** The dialog fires naturally on the first `SCShareableContent.current` call.
- **All denials** (first-launch and subsequent revocation): `UNUserNotificationCenter` banner with an "Open Settings" action that deep-links to `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`. No in-app onboarding window — the OS already shows its own first-time prompt, and a banner is less disruptive than an unsolicited modal window for repeat denials.
- Permission grants trigger a macOS-level app restart. The app stays stateless at launch apart from `UserDefaults` (autolaunch flag) so the restart is invisible.

### Error taxonomy

| Class | Examples | UI |
|-------|----------|----|
| Permission | TCC denied, TCC revoked | Notification banner with "Open Settings" action — same UI for first-time and subsequent denials |
| Transient | Window disappeared between hover and click; empty/zero-byte capture; temp write failed | Silent notification: "Capture failed — please try again"; session returns to Idle |
| Programmer | Preview.app missing; `SMAppService.register` throws | `os_log` at `.error`; notification only if user-visible |

**No modal alerts anywhere** — they steal focus and break the "click menu, shoot, done" flow.

### Logging

`Logger(subsystem: "dev.greglamb.ScreenshotButton", category: …)` with categories `capture`, `overlay`, `sink`, `launch`. Default `.debug`; release keeps `.info` and above.

### Info.plist and entitlements

- `LSUIElement = YES`
- `LSMinimumSystemVersion = 14.0`
- `NSScreenCaptureUsageDescription` — required for the TCC prompt copy
- No sandbox. No hardened-runtime exceptions beyond default.
- `CFBundleIdentifier = dev.greglamb.ScreenshotButton` (must match the cask's `zap trash:` path)

## Distribution

Fully specified in `_gitignored/macos-app-release-conventions.md`. Summary:

- **Two GitHub Actions workflows.** `build.yml` (push/PR to `main`, unsigned debug build + tests, no secrets). `release.yml` (on `v*` tag, full signed/notarized pipeline).
- **Release pipeline.** Temporary keychain → import `CERTIFICATE_P12` → `xcodebuild` Release with hardened runtime and manual signing → `notarytool submit --wait` with explicit status check and log fetch on failure → `xcrun stapler staple` → signed DMG (`ScreenshotButton-<version>.dmg`) with `Applications` symlink → compute SHA-256 → create GitHub Release → rewrite `Casks/screenshotbutton.rb` with new `version`/`sha256` → commit to `main`. Release is published *before* the cask commit so a failure in the cask-rewrite step leaves brew users on the prior version rather than a 404.
- **Cask.** `Casks/screenshotbutton.rb` with pinned `version`, pinned `sha256`, versioned URL (`releases/download/v#{version}/ScreenshotButton-#{version}.dmg`), `depends_on macos: ">= :sonoma"`, and `zap trash: ["~/Library/Preferences/dev.greglamb.ScreenshotButton.plist"]`.
- **Secrets.** `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_ID`, `APP_SPECIFIC_PASSWORD`.
- **CI vs. local dev.** Raw `xcodebuild` in CI; `xcodebuildmcp` locally for describe-ui and structured output.
- **Install.** `brew tap greglamb/macos-screenshot-button https://github.com/greglamb/macos-screenshot-button && brew install --cask screenshotbutton`. No `--no-quarantine` — notarized and stapled from v1.

## Testing strategy

Follows `project-standards`: Swift Testing (`@Test`), ≥75% unit coverage, strict TDD per task.

### Unit-tested (majority of logic)

| Component | Approach |
|---|---|
| `CaptureSession` state machine | Drive state transitions; assert observable state |
| `WindowEnumerator` | Inject `SCShareableContent`-equivalent protocol; feed fixtures |
| Hit-testing math | Pure function; `@Test(arguments:)` parametrized cases |
| Area rect normalization | Negative-drag and 5pt² cancel threshold |
| `Sink` routing | Inject `FileWriting` and `Pasteboard` protocols; zero real I/O |
| `LaunchAtLogin` | Inject `SMAppServiceAPI` protocol |
| PNG encoding | Round-trip fixture `CGImage` |
| Temp-dir cleanup | Fixture files at varying ages; assert selective deletion |

### Not unit-testable — manual / UI verification

| Thing | Why | Verification |
|---|---|---|
| TCC prompt | OS-level, not scriptable | Manual checklist in `docs/manual-test-plan.md` |
| `SCScreenshotManager` real pixels | Depends on live screen state | `/swift-dev:verify-ui` during dev; manual pre-release |
| Overlay panel rendering | Real `NSPanel` display | `xcodebuildmcp screenshot` + `describe-ui` |
| Multi-display | CI has one display | Manual test on real multi-display setup |
| Preview.app invocation | External app | Integration smoke: PNG appears in temp dir |

### Protocol wrappers around Apple APIs

Every SCK, AppKit, and `SMAppService` call is wrapped behind a narrow protocol with one real implementation and one test double. Wrappers live in the services layer; nothing in the view tree talks to SCK directly. This is the single biggest coverage lever.

### Test layout

```
ScreenshotButtonTests/
├── CaptureSessionTests.swift
├── WindowEnumeratorTests.swift
├── HitTestingTests.swift
├── AreaGeometryTests.swift
├── SinkTests.swift
├── LaunchAtLoginTests.swift
├── PNGEncodingTests.swift
├── TempCleanupTests.swift
└── Fakes/
    ├── FakeSCShareableContent.swift
    ├── FakeScreenshotManager.swift
    ├── FakeFileWriter.swift
    ├── FakePasteboard.swift
    └── FakeSMAppService.swift
```

### Coverage in CI

`xcodebuild ... -enableCodeCoverage=YES test` in `build.yml`. Parse coverage, fail below 75%. Exclude the App/MenuView/OverlayView files from the denominator — UI code without UI tests inflates denominators and encourages useless tests.

### TDD cadence

Per `superpowers:test-driven-development` and `project-standards`: each planned task is Red-Green-Refactor, one commit per passing task, no implementation without a failing test watched-fail-first.

## Open questions — none blocking implementation

The following will surface naturally during the plan/implementation phase and don't need resolving up front:

- Exact visual style of the window highlight (stroke color, fill opacity). Default: accent color 2pt stroke, accent color 10% fill. Adjust by eye during UI verification.
- Whether to also surface a notification on first launch before the user has clicked any menu item. Default: no — keep launch silent. The OS shows its own prompt the first time the user actually triggers a capture.
- Whether the menu shows a "permission not granted" indicator before the first capture attempt. Default: no — let the first attempt trigger the prompt naturally.

These are explicitly deferred to implementation judgment. If any become real design decisions, they move into this file via PR.
