# TODO

## Deferred from v1

- **Global hotkeys** for the four capture modes — scope-cut to keep v1 menu-only. No hotkey recorder UI, no collision-detection with macOS's built-in `Cmd-Shift-3/4/5`.
- **Cursor inclusion** option (currently always off; matches macOS default).
- **Sparkle auto-updates** — brew handles updates for now.
- **Configurable save location** — v1 writes to `NSTemporaryDirectory()` and hands the file to Preview; user saves via Preview's Save dialog.
- **On-screen mode indicator** during capture — relies on cursor + window-highlight cues only.

## Known limitations

- Window captures have no composited drop shadow (intentionally dropped from spec — we capture isolated window pixels via `SCScreenshotManager`, which doesn't include the system shadow).
- After granting Screen Recording permission, macOS automatically restarts the app — expected platform behavior, not a bug.
- Permission re-prompt UX is delivered via system notification; users with notifications disabled for ScreenshotButton will not see the prompt.
- Real-device Screen Recording / TCC flow has not been smoke-tested in CI; manual verification is required pre-release.

## Follow-ups discovered during implementation

- `ARCHITECTURE.md` lists module sub-directories that materialized as the matching tasks landed; keep it in sync as the layout evolves.
- The `xcode-build-server`-driven SourceKit index occasionally lags after `xcodegen generate`; `bin/regen` already runs both. If LSP diagnostics persist, run `./bin/regen` again.

## Deferred from final code review (open for v1.1)

- **Integration test for `OverlayManager`** — the most complex file in the repo (Tasks, cancellation, post-`await` state re-check) currently has zero direct tests. Coverage at the coordinator/UI seam is the highest-leverage gap.
- **Test `Notifier` permission routing** by injecting a `URLOpening` protocol so the `Open Settings` action's `NSWorkspace.open(url)` call is verifiable.
- **Re-entry handling in `OverlayManager.begin`** — currently a silent no-op when a session is already in flight. Consider dismissing the in-flight session first, or surfacing a console log.
- **`MenuView` autolaunch toggle errors** — currently swallowed with a comment promising future `Notifier` integration. Wire it through.
- **`Notifier.requestAuthorization` should fire eagerly on app launch**, not lazily on first `post`. Otherwise the first permission-denied banner can race the auth prompt.
- **`Casks/screenshotbutton.rb` `zap trash:` path** — the app currently stores nothing under `~/Library/Preferences/dev.greglamb.ScreenshotButton.plist` (autolaunch state lives there only when `LaunchAtLogin.setEnabled(true)` writes via `UserDefaults.standard`). Either drop the zap entry once verified empty, or expand it once preferences ship.
- **`MenuView` "Autolaunch" label** — macOS conventional wording is "Launch at Login" (System Settings uses exactly that).
- **`OverlayManager.displayID` extension** — falls back to `0` if `NSScreenNumber` is missing; `0` is a valid display ID. Prefer `CGMainDisplayID()` or assert.
- **`FileSink` allocates a new `DateFormatter` per call** — cache the formatter, or switch to `ISO8601DateFormatter`.
