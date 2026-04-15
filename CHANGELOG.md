# Changelog

All notable user-facing changes to ScreenshotButton are documented here.

## [Unreleased]

### Added

- Menu bar app with four capture modes: **Window to File**, **Area to File**, **Window to Clipboard**, **Area to Clipboard**.
- Per-screen click-to-select-window overlay; drag-to-draw rectangle for area mode.
- **Space** key toggles between window and area mode mid-capture; **Esc** cancels.
- File captures save a PNG to a temp folder and open it in Preview.
- Clipboard captures copy the image to the system pasteboard as `NSImage`.
- **Autolaunch** toggle (backed by `SMAppService`) for launch-at-login.
- Notification-based handling for Screen Recording permission denial, with an "Open Settings" action.
- Stale temp screenshots older than 24h are pruned automatically on app launch.
- Signed and notarized distribution via Homebrew cask hosted in this repo.
- Mid-capture Screen Recording revocation surfaces the same notification banner with an "Open Settings" action as a denied first capture.

### Fixed (pre-release review)

- Release workflow now bumps the cask **before** publishing the GitHub release, with `git fetch && checkout main && pull --ff-only` to prevent racing concurrent pushes; users never see a release whose cask points at the prior version.
- Launch-time temp pruning runs in a structured `.task(priority: .background)` rather than an unstructured `Task.detached(...).value` nested inside `.task`.
- `NSScreen.displayID` helper falls back to `CGMainDisplayID()` instead of `0` (which is not a valid display ID) when `NSScreenNumber` is missing, and logs the fallback via `os.Logger` so real regressions are visible in Console.
- Launch-at-Login toggle failures now surface via a notification banner instead of silently reverting, so the user knows why the toggle snapped back.

### Changed

- Repository slug renamed from `macos-screenshot-button` to `macos-screenshot-button-app`. Install command is now:
  ```
  brew tap greglamb/macos-screenshot-button-app https://github.com/greglamb/macos-screenshot-button-app
  brew install --cask screenshotbutton
  ```
  The Xcode target, bundle identifier (`dev.greglamb.ScreenshotButton`), and DMG filename are unchanged.
- Menu label changed from "Autolaunch" to "Launch at Login" to match macOS System Settings wording.
