# Changelog

All notable user-facing changes to ScreenshotButton are documented here.

## [Unreleased]

### Added

- Menu footer now shows the running app version (e.g. "Version 0.0.6"). Released builds display the git-tag version (via `MARKETING_VERSION` on the release workflow's `xcodebuild` command); local dev builds show `dev-<short-sha>` (stamped by a Project.yml postBuildScript). No manual version bumps anywhere — tag → push → published version visible in the menu.

### Changed

### Fixed

- Window captures no longer produce an oversized PNG on non-Retina (e.g. HDMI) external monitors. The capture now uses `SCContentFilter.pointPixelScale` rather than a hardcoded `* 2`, so the output matches the filter's native pixel area on every display scale — window content previously ended up stuck in the top-left quadrant of a canvas twice the intended size on non-Retina displays.
- Single click on a window now registers properly during window selection mode. Previously, the first click was consumed by the `nonactivatingPanel` as a window-key transition, requiring a second click to actually select the window. Now `acceptsFirstMouse(for:)` on the overlay view allows the first click to fire `mouseDown` directly.

### Removed

## [v0.0.6] - 2026-04-16

### Fixed

- Cursor change during capture now actually takes effect: switched from `addCursorRect`/`NSCursor.set()` (which the window server clobbers on borderless `nonactivatingPanel`s at `.screenSaver` level) to `NSCursor.push()`/`pop()` keyed to the overlay-present/dismiss/Space-toggle lifecycle. Crosshair in area mode, pointing hand in window mode.
- Window picker now only highlights normal-level app windows visible on screen. Excludes the desktop wallpaper, dock, menu bar, notification center, floating panels, and sub-pixel helper windows. When overlapping windows share a click point, the **frontmost** window wins — z-order sourced from `CGWindowListCopyWindowInfo` (documented front-to-back) rather than SCK's undocumented ordering or area heuristics.

## [v0.0.5] - 2026-04-16

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

### Fixed

- Release workflow now bumps the cask **before** publishing the GitHub release, with `git fetch && checkout main && pull --ff-only` to prevent racing concurrent pushes; users never see a release whose cask points at the prior version.
- Launch-time temp pruning runs in a structured `.task(priority: .background)` rather than an unstructured `Task.detached(...).value` nested inside `.task`.
- `NSScreen.displayID` helper falls back to `CGMainDisplayID()` instead of `0` (which is not a valid display ID) when `NSScreenNumber` is missing, and logs the fallback via `os.Logger` so real regressions are visible in Console.
- Launch-at-Login toggle failures now surface via a notification banner instead of silently reverting, so the user knows why the toggle snapped back.
- `Notifier.requestAuthorization` now fires eagerly at app launch (in parallel with temp-file pruning via `async let`), so the first permission-denied banner can't race the auth prompt.
- Cursor now changes during capture: **crosshair** in area mode, **pointing hand** in window mode. Set directly via `NSCursor.set()` from `cursorUpdate` and `mouseMoved` because cursor-rects don't reliably propagate through borderless `nonactivatingPanel`s at `.screenSaver` level. Toggles live with **Space**.
- Window picker now excludes minimized and hidden windows — only windows visible on screen are selectable.
- Window highlight and area capture now correctly handle the Quartz↔Cocoa Y-axis flip. ScreenCaptureKit returns frames in top-left-origin Quartz space; the rest of the app uses bottom-left-origin Cocoa space. The mismatch was making the picker highlight whichever windows happened to overlap the inverted Y, and area captures were grabbing the wrong region of the screen. `OverlayManager` now flips at the SCK boundary so hit-testing, highlight drawing, and `SCStreamConfiguration.sourceRect` all share one coordinate space.
- CI cask-bump step now uses POSIX `[[:space:]]` in the `sed -E` regex (BSD `sed` on macOS doesn't understand the `\s` extension), and computes the DMG SHA *after* `codesign --force` runs, so brew installs match the file actually published in the release.

### Changed

- Repository slug renamed from `macos-screenshot-button` to `macos-screenshot-button-app`. Install command is now:
  ```
  brew tap greglamb/macos-screenshot-button-app https://github.com/greglamb/macos-screenshot-button-app
  brew install --cask screenshotbutton
  ```
  The Xcode target, bundle identifier (`dev.greglamb.ScreenshotButton`), and DMG filename are unchanged.
- Release workflow now gracefully degrades when signing secrets are absent: publishes an unsigned DMG with Gatekeeper-bypass instructions in the release notes instead of failing. Homebrew cask is not updated for unsigned releases, so `brew install` keeps pointing at the most recent signed build.
