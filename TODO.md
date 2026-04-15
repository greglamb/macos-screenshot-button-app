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
- **Re-entry handling in `OverlayManager.begin`** — currently a silent no-op when a session is already in flight. Consider dismissing the in-flight session first, or surfacing a console log.
- **Tighter window-picker filtering** — the current `SCShareableContent` filter excludes off-screen/minimized/untitled windows, but still admits sub-pixel windows (tooltips, invisible helpers) and non-normal layers (menu bar, floating panels). If users report picking chrome, add `frame.width/height >= 20` and `windowLayer == 0`.
- **`Casks/screenshotbutton.rb` `zap trash:` audit (resolved 2026-04-14):** Confirmed `LaunchAtLogin.setEnabled` writes the `launchAtLogin` flag via `UserDefaults.standard`, which lands in `~/Library/Preferences/dev.greglamb.ScreenshotButton.plist`. The existing `zap trash:` entry is correct; no change needed.
