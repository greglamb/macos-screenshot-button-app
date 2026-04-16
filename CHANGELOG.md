# Changelog

All notable user-facing changes to ScreenshotButton are documented here.

## [Unreleased]

### Added

- App icon — a blue-gradient rounded square with a white viewfinder motif. Generated programmatically via `bin/gen-icon` so it can be regenerated reproducibly without a design tool.
- Menu bar app with four capture modes: **Window to File**, **Area to File**, **Window to Clipboard**, **Area to Clipboard**.
- Per-screen click-to-select-window overlay; drag-to-draw rectangle for area mode.
- **Space** key toggles between window and area mode mid-capture; **Esc** cancels.
- File captures save a PNG to a temp folder and open it in Preview.
- Clipboard captures copy the image to the system pasteboard as `NSImage`.
- **Launch at Login** toggle (backed by `SMAppService`).
- Notification-based handling for Screen Recording permission denial, with an "Open Settings" action.
- Stale temp screenshots older than 24h are pruned automatically on app launch.
- Signed and notarized distribution via Homebrew cask hosted in this repo.
- Mid-capture Screen Recording revocation surfaces the same notification banner with an "Open Settings" action as a denied first capture.

### Fixed (pre-release review)

- Release workflow now bumps the cask **before** publishing the GitHub release, with `git fetch && checkout main && pull --ff-only` to prevent racing concurrent pushes; users never see a release whose cask points at the prior version.
- Launch-time temp pruning runs in a structured `.task(priority: .background)` rather than an unstructured `Task.detached(...).value` nested inside `.task`.
- `NSScreen.displayID` helper falls back to `CGMainDisplayID()` instead of `0` (which is not a valid display ID) when `NSScreenNumber` is missing, and logs the fallback via `os.Logger` so real regressions are visible in Console.
- Launch-at-Login toggle failures now surface via a notification banner instead of silently reverting, so the user knows why the toggle snapped back.
- `Notifier.requestAuthorization` now fires eagerly at app launch (in parallel with temp-file pruning via `async let`), so the first permission-denied banner can't race the auth prompt.
- Cursor now changes during capture: **crosshair** in area mode, **pointing hand** in window mode. Set directly via `NSCursor.set()` from `cursorUpdate` and `mouseMoved` because cursor-rects don't reliably propagate through borderless `nonactivatingPanel`s at `.screenSaver` level. Toggles live with **Space**.
- Window picker now excludes minimized and hidden windows — only windows visible on screen are selectable.
- Window highlight and area capture now correctly handle the Quartz↔Cocoa Y-axis flip. ScreenCaptureKit returns frames in top-left-origin Quartz space; the rest of the app uses bottom-left-origin Cocoa space. The mismatch was making the picker highlight whichever windows happened to overlap the inverted Y, and area captures were grabbing the wrong region of the screen. `OverlayManager` now flips at the SCK boundary so hit-testing, highlight drawing, and `SCStreamConfiguration.sourceRect` all share one coordinate space.

### Changed

- Repository slug renamed from `macos-screenshot-button` to `macos-screenshot-button-app`. Install command is now:
  ```
  brew tap greglamb/macos-screenshot-button-app https://github.com/greglamb/macos-screenshot-button-app
  brew install --cask screenshotbutton
  ```
  The Xcode target, bundle identifier (`dev.greglamb.ScreenshotButton`), and DMG filename are unchanged.
- Release workflow now gracefully degrades when signing secrets are absent: publishes an unsigned DMG with Gatekeeper-bypass instructions in the release notes instead of failing. Homebrew cask is not updated for unsigned releases, so `brew install` keeps pointing at the most recent signed build.
