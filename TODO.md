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
