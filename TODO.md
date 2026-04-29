# TODO

## Deferred from v1

- **Global hotkeys** for the four capture modes — scope-cut to keep v1 menu-only. No hotkey recorder UI, no collision-detection with macOS's built-in `Cmd-Shift-3/4/5`. (First slice — Area-to-Clipboard only — designed 2026-04-28: `docs/superpowers/specs/2026-04-28-area-to-clipboard-hotkey-design.md`.)
- **Global hotkeys for the remaining three modes** (Window-to-File, Area-to-File, Window-to-Clipboard) — A→C ships in v0.0.8; persistence is dictionary-typed so adding rows to `SettingsView` is a UI-only change.
- **Cursor inclusion** option (currently always off; matches macOS default).
- **Sparkle auto-updates** — brew handles updates for now.
- **Configurable save location** — v1 writes to `NSTemporaryDirectory()` and hands the file to Preview; user saves via Preview's Save dialog.
- **On-screen mode indicator** during capture — relies on cursor + window-highlight cues only.

## Known limitations

- Window captures have no composited drop shadow (intentionally dropped from spec — we capture isolated window pixels via `SCScreenshotManager`, which doesn't include the system shadow).
- After granting Screen Recording permission, macOS automatically restarts the app — expected platform behavior, not a bug.
- Permission re-prompt UX is delivered via system notification; users with notifications disabled for ScreenshotButton will not see the prompt.
- Real-device Screen Recording / TCC flow has not been smoke-tested in CI; manual verification is required pre-release.
- **Live revocation of Input Monitoring permission is not detected.** macOS does not notify processes when a TCC permission is revoked while the app is running. The hotkey silently stops firing; the in-Settings banner only updates on the next binding change or app relaunch. A polling probe would be overkill for one hotkey.
- **Cross-app hotkey collisions are not detected.** `NSEvent.addGlobalMonitorForEvents` is observe-only — if another app has bound the same key globally, both fire on the same keystroke. Documented constraint of the chosen API; would require Carbon `RegisterEventHotKey` to detect.
- **App Sandbox not adopted.** If sandbox is later required (e.g. for App Store distribution), the new hotkey feature will need the `com.apple.security.device.input-monitoring` entitlement and a corresponding provisioning profile change.

## Follow-ups discovered during implementation

- `ARCHITECTURE.md` lists module sub-directories that materialized as the matching tasks landed; keep it in sync as the layout evolves.
- The `xcode-build-server`-driven SourceKit index occasionally lags after `xcodegen generate`; `bin/regen` already runs both. If LSP diagnostics persist, run `./bin/regen` again.

## Deferred from HDMI-capture fixes (2026-04-17)

- **Capture-dimension debug logging in `SCScreenshotManagerAdapter`** — the `pointPixelScale`/`width`/`height` wiring is now correct, but silent when wrong. A single `os.Logger.debug("capture dims: \(w)x\(h) @ scale=\(filter.pointPixelScale)")` gated `#if DEBUG` would surface a future regression of this class without shipping verbose logs to users. Flagged during Task 2 code review; out of scope for the fix commit itself.

## Cursor change/hide during capture overlay — NOT SHIPPING (2026-04-20)

The `.pointingHand` / `.crosshair` cursor swap during window/area capture has never been visibly working on the development hardware (macOS 26.2, multi-display with HDMI + Retina). The v0.0.6 CHANGELOG claimed to have fixed this; the fix never actually took effect but wasn't caught because no visual verification happened.

On 2026-04-19/20 we attempted ~15 distinct approaches over a long debug session, all unsuccessful:

1. `addCursorRect` in `resetCursorRects()`.
2. `.cursorUpdate` tracking-area option + `cursorUpdate(with:)` override calling `.set()`.
3. `cursor.set()` in `mouseMoved`.
4. `NSApp.windows.forEach { $0.disableCursorRects() }` around push/pop.
5. Layer `backgroundColor` alpha sweeps (0.05, 0.15, 1.0).
6. Panel `isOpaque = true` with near-zero-alpha background.
7. `NSPanel` → `NSWindow` (dropped `.nonactivatingPanel`).
8. `canBecomeMain = true`.
9. Explicit `NSApp.activate(ignoringOtherApps: true)` before `makeKeyAndOrderFront`.
10. Delaying `pushCursor()` one runloop tick after `makeKeyAndOrderFront` via `Task { @MainActor }`.
11. Panel level `.screenSaver` → `.statusBar`.
12. Panel `backgroundColor` `.clear` → `NSColor.black.withAlphaComponent(0.01)` for hit-testing.
13. Full Capso-pattern mirror: `NSCursor.hide()` + custom crosshair reticle, `_setPreventsActivation:` private SPI, tracking area installed in `init()`, `invalidateCursorRects` + `displayIfNeeded` in `prepareForPresentation`.
14. `makeFirstResponder` explicit call.
15. Various combinations of the above.

Verified-correct state from logs on the final attempt:
- `NSApp.isActive = true`, panel is `keyWindow`, tracking area dispatches events correctly.
- `cursorUpdate(with:)` fires on tracking-area entry.
- `NSCursor.set()` IS accepted at the app-process level — `NSCursor.current === <our cursor>` after `set()`.
- But `NSCursor.currentSystem` is a **different** `NSCursor` instance — the window server renders a cursor we didn't ask for.
- `NSCursor.hide()` called with no un-hide in between — cursor stays visible anyway.

Capso (github.com/lzhgus/Capso) ships with the exact same hide-and-reticle pattern and it works for them. Something is different between their environment and ours that we haven't identified. Candidates: macOS 26.2 behavior change, per-user/per-machine system state, HDMI display driver quirk, accessibility setting, or a subtle code path we missed.

**Shipped posture:** no cursor change, no reticle, no cursor hiding. The system arrow shows in both window and area modes. The hovered-window highlight rectangle (window mode) and the dragged selection rectangle (area mode) provide visual feedback — same as it has been since v0.0.6.

**Next steps for a future attempt:**
- Reproduce on a different macOS machine to narrow whether it's environmental. If it works elsewhere, look for per-user state (`defaults`, `tccutil`, accessibility settings).
- Investigate `CGSSetWindowProperty` / private `HIServices` cursor SPIs that Shottr/CleanShot may use.
- Try without `LSUIElement` for a debug session: flip to `.regular` activation policy temporarily and see if cursor works. If yes, the cause is LSUIElement-specific and there may be a workaround.
- Add Developer Forums / Radar thread; Apple engineers may be able to clarify the cursor-dispatch rules.

Full history preserved in git on the `fix/capture-bugs` branch (commits from 2026-04-19 and 2026-04-20 in the `NSCursor` / `OverlayView` / `OverlayPanel` cursor attempts). The panel config, `Project.yml` (Developer ID signing), and convention docs from this session all ship — only the cursor code is reverted.

## Deferred from final code review (open for v1.1)

- **Integration test for `OverlayManager`** — the most complex file in the repo (Tasks, cancellation, post-`await` state re-check) currently has zero direct tests. Coverage at the coordinator/UI seam is the highest-leverage gap.
- **Re-entry handling in `OverlayManager.begin`** — currently a silent no-op when a session is already in flight. Consider dismissing the in-flight session first, or surfacing a console log.
- **Tighter window-picker filtering** — the current `SCShareableContent` filter excludes off-screen/minimized/untitled windows, but still admits sub-pixel windows (tooltips, invisible helpers) and non-normal layers (menu bar, floating panels). If users report picking chrome, add `frame.width/height >= 20` and `windowLayer == 0`.
- **`Casks/screenshotbutton.rb` `zap trash:` audit (resolved 2026-04-14):** Confirmed `LaunchAtLogin.setEnabled` writes the `launchAtLogin` flag via `UserDefaults.standard`, which lands in `~/Library/Preferences/dev.greglamb.ScreenshotButton.plist`. The existing `zap trash:` entry is correct; no change needed.
- **`SettingsView` accessibility label on "Open Settings" button** — flagged in Task 10 code review (2026-04-28). The Picker has `.accessibilityLabel("Area-to-Clipboard hotkey")`; the banner's `Button("Open Settings")` should also get `.accessibilityLabel("Open Input Monitoring settings")` so VoiceOver users encountering the row out of context disambiguate which "Settings" is being opened.
- **`SettingsView` fixed-frame vs. Dynamic Type** — flagged in Task 10 code review (2026-04-28). The `.frame(width: 480, height: 260)` is the spec'd choice for v1 and matches the macOS preferences pattern, but at very large Dynamic Type / accessibility text sizes the long Fn-tip text could clip. Re-evaluate after Task 13's manual verification on real hardware. If clipping appears, swap to `.frame(minWidth: 480, minHeight: 260)`.

## Rejected approaches

### Area-to-Clipboard hotkey design (2026-04-28)

Considered and rejected during brainstorming for `docs/superpowers/specs/2026-04-28-area-to-clipboard-hotkey-design.md`:

- **Carbon `RegisterEventHotKey`** — initial recommendation. Modern API preferred by user; the "intercept" property of Carbon stops mattering once Fn+F-key is the input gesture (no competing system action to step on).
- **Submenu inside the menu-bar dropdown (no Settings window)** — cheaper to ship but contradicts the user's explicit request for "an options screen opened from the drop down menu." Doesn't scale past one row.
- **Hotkey recorder UI (any modifier + any key)** — overbuilt for a single-binding v1. `Picker<F1…F19>` matches "function key" framing exactly.
- **F-key + optional modifiers** — briefly recommended; rejected by user in favor of plain F-keys with Fn handled by the OS.
- **`PreferencesStore` protocol around `UserDefaults`** — YAGNI. Tests inject `UserDefaults(suiteName: UUID().uuidString)` directly per Apple's documented testing pattern.
- **Expose all four capture modes in v1** — rejected in favor of A→C only. Persistence is dictionary-typed so adding rows is a UI-only change later.
- **Live revocation polling** — overkill for one hotkey. We surface denial state on the next `apply` call instead.
