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
