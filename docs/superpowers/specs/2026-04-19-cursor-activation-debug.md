# Cursor Activation Debug — Design

**Date:** 2026-04-19
**Status:** Spec
**Replaces:** the portion of `docs/superpowers/plans/2026-04-17-capture-bug-fixes.md` covering Task 3 (cursor reassert via `cursorUpdate`). That task landed but did not visibly change the cursor on the user's hardware — the root cause is architectural, not a missing API call.

## Problem

The crosshair / pointing-hand cursor change has **never been visibly working** in ScreenshotButton on the primary development machine, on either the Retina laptop display or an external HDMI monitor. This contradicts the `v0.0.6` CHANGELOG claim that the cursor fix is functional.

Three speculative fixes were attempted during the 2026-04-17 / 2026-04-18 session:

1. Add `.cursorUpdate` tracking-area option + `cursorUpdate(with:)` override calling `NSCursor.set()` — no visible change.
2. Add `NSApp.windows.forEach { $0.disableCursorRects() }` around push/pop — no visible change, suppressed events further.
3. Revert #2, keep #1 — no visible change.

Per `superpowers:systematic-debugging`, three failed fixes signal an architectural problem, not a bug in the next hypothesis. We stop guessing and find the root cause.

## Root-cause hypothesis

ScreenshotButton is a `MenuBarExtra` app with `LSUIElement: true` (`Project.yml:45`). LSUIElement apps:

- Do not appear in the Dock.
- Cannot become the "active" foreground app through the normal `makeKeyAndOrderFront(_:)` path.
- Panels spawned from them inherit accessory status — a borderless `.nonactivatingPanel` at `.screenSaver` level can become *key within our app* (we have `canBecomeKey: true`), but the window server still routes cursor-resolution to whichever app was foreground when we presented the overlay (the user's active app — Safari, Chrome, etc.).

Consequence: `NSCursor.push()` pushes to our app's cursor stack, `NSCursor.set()` sets our cursor as current, and `NSView.cursorUpdate(with:)` overrides correctly — **but the system cursor the user sees is owned by the foreground app's cursor rects, not ours.** Our cursor machinery runs invisibly.

This also explains why mouse-down and key-down events DO work: those go through our key window's first-responder chain, which is independent of app activation.

**Supporting evidence (circumstantial):**
- v0.0.6 code review passed with no hardware verification documented.
- Every push/pop or set/cursorUpdate variant has produced the same null result, which is consistent with "the cursor system runs but isn't rendered" rather than "we're using the wrong API."

## Diagnostic plan (Phase 1)

Before changing architecture, instrument to confirm the hypothesis. Two `Logger.info` calls:

1. `OverlayManager.pushCursor()` — logs mode, `NSApp.isActive`, and `NSApp.keyWindow?.className`.
2. `OverlayView.cursorUpdate(with:)` — logs mode and `self.window?.isKeyWindow`.

One rebuild, one TCC grant. The user runs one capture. We query `/usr/bin/log show --predicate 'process == "ScreenshotButton"' --last 2m --info`.

**Three possible outcomes map to three different root causes:**

| Log evidence | Root cause | Next step |
|---|---|---|
| `pushCursor` fires, `cursorUpdate` silent | Hypothesis confirmed: our panel isn't receiving cursor events because the app isn't active | Apply Phase 2 fix |
| `pushCursor` fires, `cursorUpdate` fires, cursor still visually unchanged | Hypothesis refuted; cursor is being set but clobbered at a lower layer we haven't identified | Stop, regroup with user |
| `pushCursor` doesn't fire | Overlay-present code path is broken — entirely different bug | Stop, investigate presentation flow |

**Pre-committed discipline:** if the logs are ambiguous, we DO NOT apply the Phase 2 fix and hope. We report ambiguity back and decide together. Per the systematic-debugging skill: no fix #4 without a clear root cause.

## Fix plan (Phase 2 — only on confirmed hypothesis)

Single change: in `OverlayManager.present()`, immediately before the current `pushCursor()` call, invoke `NSApp.activate(ignoringOtherApps: true)`. No other code changes.

**Rationale:** `activate(ignoringOtherApps:)` makes an LSUIElement app foreground for the duration it has visible windows. Once our overlay panel is active and key AND our app is active, the window server dispatches cursor events to us and our existing push + cursorUpdate machinery becomes visible.

**Side effect:** the previously-active app (e.g., Safari) loses focus for the duration of the overlay. Since the user has just clicked a menu to *initiate* a capture, they have already interrupted their flow — this is acceptable. When `tearDown()` runs, the panel is ordered out; macOS naturally restores the prior foreground app because we have no remaining visible windows to hold focus.

**What we are NOT changing:**
- No switch to `.pointerStyle` (macOS 15+ only; we target macOS 14).
- No SwiftUI rewrite of the overlay.
- No modification to `NSCursor.push`/`pop` or the `cursorUpdate(with:)` override — those remain.
- No `disableCursorRects()` — the previously-reverted fix stays reverted.
- No explicit `NSApp.deactivate()` call. Let AppKit handle focus return.

## Rebuild and TCC strategy

Ad-hoc signed rebuilds invalidate TCC grants for this bundle ID. We have paid this cost four times in this session. To minimize further:

1. **Rebuild once** with the diagnostic logging added.
2. Copy the built `.app` to `build_debug_launch/` (non-hidden path, already validated to avoid `.worktrees/` hidden-path complications).
3. `tccutil reset All dev.greglamb.ScreenshotButton` — fully reset.
4. `lsregister -f -R` the non-hidden copy.
5. User launches, grants Screen Recording once, runs one capture.
6. Read logs. Decision gate.
7. **If fix applied:** one more rebuild with logging removed + `NSApp.activate(...)` added. Copy, re-register, grant once more, verify.

Total budget: 2 rebuilds max from this point. If we exceed that without confirmed resolution, we stop and ship what we have.

## Scope

**In scope:**
- Diagnostic logging (temporary, removed in the fix commit).
- `NSApp.activate(ignoringOtherApps: true)` in `OverlayManager.present()`.
- Updated CHANGELOG entry reflecting the real root cause and fix.
- TODO.md update if we defer the issue.

**Out of scope (this spec):**
- Any other cursor API changes.
- Panel-level configuration changes (styleMask, level, canBecomeKey).
- Tests — the fix is a single-line API call whose observable behavior is window-server state. Manual verification is the only reliable signal; automated tests would not cover the actual bug.
- Handling focus-restoration edge cases (e.g., what if the user had no active app). Accept AppKit defaults.

## Phase 1 outcome (recorded 2026-04-19)

**Outcome B — original hypothesis refuted.** Log evidence from the instrumented build (`dev-c3cf1d2`):

```
pushCursor: mode=window NSApp.isActive=true keyWindow=ScreenshotButton.OverlayPanel
cursorUpdate fired: mode=window windowIsKey=true
```

The LSUIElement app IS active, the overlay panel IS key, the `cursorUpdate(with:)` event IS firing on the correct view. `NSApp.activate(ignoringOtherApps: true)` would be a no-op.

## Revised hypothesis

`.cursorUpdate` as a tracking-area option fires **once per cursor entry** into the tracking area, not on every cursor move. Our overlay covers the whole screen — the cursor enters once, never exits. After that single firing of `cursor.set()`, the window server's periodic cursor-rect resolution cycle runs (documented in Avitzur's lldb trace at SO#61984959). That cycle walks registered cursor rects on the view under the cursor and returns the matching rect's cursor, or default arrow if none match.

Our `OverlayView` has **no cursor rects registered**. We deliberately avoided `addCursorRect(_:cursor:)` based on a comment inherited from v0.0.5 claiming the window server clobbers `addCursorRect` results on borderless `nonactivatingPanel`s at `.screenSaver` level. But the v0.0.6 push/pop "fix" never actually rendered the cursor visibly on the development hardware — the CHANGELOG claim was fiction. We cannot trust the v0.0.5 comment as an established fact.

Consequence: on the first cursorUpdate entry, our cursor flashes for less than one frame; then the resolution cycle returns default arrow because we have no cursor rect. The user sees default arrow throughout.

## Revised fix (replaces Phase 2 `NSApp.activate`)

Override `resetCursorRects()` on `OverlayView` and call `addCursorRect(bounds, cursor: modeCursor)`. When `didPressSpace()` toggles the mode, call `self.window?.invalidateCursorRects(for: self)` on each overlay view so the new mode's cursor rect is installed on the next resolution cycle.

Keep the `cursorUpdate(with:)` override in place as a belt-and-suspenders initial-assert; keep the diagnostic logging through this rebuild so we can confirm `resetCursorRects` fires and (if fix works) remove logging in a follow-up commit.

Drop the `NSApp.activate(ignoringOtherApps: true)` plan entirely.

## Acceptance criteria

After the fix commit:

- When the user invokes Window to File / Area to File / Window to Clipboard / Area to Clipboard, the system cursor visibly changes to pointing-hand (window modes) or crosshair (area modes).
- Space toggle between modes visibly switches the cursor.
- On dismiss (Esc, click-empty-area, capture commit), the cursor returns to whatever the system wants next (usually arrow).
- No regression in single-click window selection (the Task 3 / `acceptsFirstMouse` fix from 2026-04-17).
- No regression in capture output dimensions (the Task 1 / `pointPixelScale` fix from 2026-04-17).
- All existing tests pass.

If any of these fail, the fix is not done.
