# Cursor Activation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the mode cursor (crosshair in area mode, pointing hand in window mode) actually render during capture — by calling `NSApp.activate(ignoringOtherApps: true)` so the LSUIElement app's cursor stack is honored by the window server. Validate the architectural hypothesis with diagnostic logging before applying the fix; abort to the user if logs contradict the hypothesis.

**Architecture:** Two phases with a hard decision gate. Phase 1 adds two `Logger.info` calls (one in `pushCursor()`, one in `cursorUpdate(with:)`), one rebuild, user runs one capture, we query the unified log. Evidence drives Phase 2. Phase 2 (only on confirmed hypothesis) adds a single `NSApp.activate(...)` call in `OverlayManager.present()` before `pushCursor()`, removes the diagnostic logging, and updates CHANGELOG.

**Tech Stack:** Swift 6 strict concurrency, AppKit (`NSApplication`, `NSCursor`, `NSPanel`), `os.Logger`, ad-hoc code signing with `tccutil`/`lsregister` for TCC management.

---

## File Structure

**Modified (Phase 1 — temporary):**
- `ScreenshotButton/ViewModels/OverlayManager.swift` — add Logger call in `pushCursor()`.
- `ScreenshotButton/Views/OverlayView.swift` — add Logger import + Logger call in `cursorUpdate(with:)`.

**Modified (Phase 2):**
- `ScreenshotButton/ViewModels/OverlayManager.swift` — add `NSApp.activate(...)` before `pushCursor()` in `present()`; remove the Phase 1 Logger line.
- `ScreenshotButton/Views/OverlayView.swift` — remove Phase 1 Logger line and the `import os` that went with it (if it was added just for Phase 1).
- `CHANGELOG.md` — replace the current cursor-entry text to reflect the actual root cause.

**No new files. No test files.** The spec explicitly scopes out automated tests because the fix's observable behavior is window-server state — the cursor appearing visually — which cannot be meaningfully unit-tested with AppKit fakes. Manual verification through the rebuild/launch loop is the acceptance gate.

---

## Task 1: Add diagnostic logging

**Files:**
- Modify: `ScreenshotButton/ViewModels/OverlayManager.swift`
- Modify: `ScreenshotButton/Views/OverlayView.swift`

- [ ] **Step 1: Add the log call in `pushCursor()`**

Modify `ScreenshotButton/ViewModels/OverlayManager.swift`. The existing `pushCursor()` method currently reads:

```swift
    private func pushCursor() {
        guard !cursorPushed else { return }
        let cursor: NSCursor = mode == .area ? .crosshair : .pointingHand
        cursor.push()
        cursorPushed = true
    }
```

Replace it with:

```swift
    private func pushCursor() {
        guard !cursorPushed else { return }
        let cursor: NSCursor = mode == .area ? .crosshair : .pointingHand
        overlayLog.info("pushCursor: mode=\(String(describing: self.mode), privacy: .public) NSApp.isActive=\(NSApp.isActive) keyWindow=\(NSApp.keyWindow?.className ?? "nil", privacy: .public)")
        cursor.push()
        cursorPushed = true
    }
```

`overlayLog` already exists at the top of the file (line 6):
```swift
private let overlayLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "overlay")
```
No new import needed.

- [ ] **Step 2: Add the log call in `cursorUpdate(with:)`**

Modify `ScreenshotButton/Views/OverlayView.swift`. First, add the `os` import and a private logger at the top of the file. The current file starts:

```swift
import AppKit
import CoreGraphics

final class OverlayView: NSView {
```

Replace those first four lines with:

```swift
import AppKit
import CoreGraphics
import os

private let cursorDebugLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "cursor-debug")

final class OverlayView: NSView {
```

Then find the existing `cursorUpdate(with:)` override. It currently reads:

```swift
    override func cursorUpdate(with event: NSEvent) {
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }
```

Replace with:

```swift
    override func cursorUpdate(with event: NSEvent) {
        let modeStr = (manager?.mode).map { "\($0)" } ?? "nil"
        cursorDebugLog.info("cursorUpdate fired: mode=\(modeStr, privacy: .public) windowIsKey=\(self.window?.isKeyWindow == true)")
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }
```

- [ ] **Step 3: Run full test suite to confirm no compile regressions**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ScreenshotButton/ViewModels/OverlayManager.swift \
        ScreenshotButton/Views/OverlayView.swift
git commit -m "chore: add diagnostic logging for cursor activation debug

Temporary instrumentation to verify whether pushCursor() fires and
cursorUpdate(with:) dispatches while the LSUIElement app is inactive.
Will be removed in the Phase 2 fix commit. See
docs/superpowers/specs/2026-04-19-cursor-activation-debug.md."
```

---

## Task 2: Build, register, launch the instrumented build

**Files:** none — this task is environment orchestration per the debug-workflow convention in `_gitignored/conventions/debug-workflow.md`.

- [ ] **Step 1: Kill any running ScreenshotButton process**

```bash
pkill -x ScreenshotButton 2>/dev/null; sleep 1; pgrep -x ScreenshotButton || echo "clean"
```

Expected: `clean` (no PID listed).

- [ ] **Step 2: Build Debug into `build_debug/`**

```bash
xcodebuild -project ScreenshotButton.xcodeproj \
  -scheme ScreenshotButton \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath build_debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Copy the built `.app` to a non-hidden path**

Launch Services can be flaky about `.app` bundles inside hidden directories (`.worktrees/`). Copy to a stable non-hidden path the current session has already validated:

```bash
SRC="$(pwd)/build_debug/Build/Products/Debug/ScreenshotButton.app"
DST_DIR="/Users/glamb/Repositories/macos-screenshot-button/build_debug_launch"
mkdir -p "$DST_DIR"
rm -rf "$DST_DIR/ScreenshotButton.app"
ditto "$SRC" "$DST_DIR/ScreenshotButton.app"
```

Expected: no output, exit 0.

- [ ] **Step 4: Verify the stamped dev version matches HEAD**

```bash
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  "/Users/glamb/Repositories/macos-screenshot-button/build_debug_launch/ScreenshotButton.app/Contents/Info.plist"
echo "---"
git rev-parse --short HEAD
```

Expected: both values match (the PlistBuddy output will be `dev-<short-sha>`).

- [ ] **Step 5: Full TCC reset for this bundle**

```bash
tccutil reset ScreenCapture dev.greglamb.ScreenshotButton 2>&1 | tail -1
tccutil reset All dev.greglamb.ScreenshotButton 2>&1 | tail -1
```

Expected: two `Successfully reset ...` lines.

- [ ] **Step 6: Force-register the non-hidden copy with Launch Services**

```bash
APP="/Users/glamb/Repositories/macos-screenshot-button/build_debug_launch/ScreenshotButton.app"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R "$APP"
```

Expected: no output, exit 0.

- [ ] **Step 7: Launch and verify the correct binary is running**

```bash
APP="/Users/glamb/Repositories/macos-screenshot-button/build_debug_launch/ScreenshotButton.app"
open -n "$APP"
sleep 2
PID=$(pgrep -x ScreenshotButton)
echo "PID: $PID"
lsof -p "$PID" 2>/dev/null | grep "MacOS/ScreenshotButton$" | head -1
```

Expected: the `lsof` line ends with `/build_debug_launch/ScreenshotButton.app/Contents/MacOS/ScreenshotButton` (NOT a DerivedData path or `.worktrees/` path).

---

## Task 3: Gather evidence and decide

**Files:** none — this task is human-in-the-loop.

- [ ] **Step 1: Ask the user to trigger one capture**

Ask:
> "Please click the menu bar icon and choose **Window to File**. Hover over a window for a moment (you do not need to click). Then either click a window to capture or press Esc to cancel. Let me know when you've done this."

Wait for the user's confirmation.

- [ ] **Step 2: Grant TCC if prompted**

If macOS prompts for Screen Recording, the user grants once. macOS may auto-restart the app via "Quit & Reopen" — that's expected. After the restart, the user should repeat the menu click one more time (this is the first capture that actually proceeds past the TCC gate).

- [ ] **Step 3: Query the unified log**

```bash
/usr/bin/log show --predicate 'process == "ScreenshotButton"' --last 5m --info --style compact 2>&1 | grep -E "pushCursor|cursorUpdate fired" | head -40
```

- [ ] **Step 4: Decision gate**

Interpret the output against the spec's three outcomes (`docs/superpowers/specs/2026-04-19-cursor-activation-debug.md` Diagnostic plan table):

**Outcome A — hypothesis confirmed.** Log shows `pushCursor: ...` line(s) but ZERO `cursorUpdate fired` lines, even though the user moved the cursor over the overlay. Proceed to Task 4.

**Outcome B — hypothesis refuted.** Log shows BOTH `pushCursor` and `cursorUpdate fired` lines, but the cursor still did not visibly change on the user's screen. STOP. Do not proceed to Task 4. Report the ambiguity to the user verbatim and re-enter the brainstorming skill to form a new hypothesis.

**Outcome C — presentation broken.** Log shows NO `pushCursor` line at all. STOP. The overlay-present code path is broken — an entirely different bug. Do not proceed. Report to the user, examine `OverlayManager.present()` and `begin(mode:sink:)`.

**Ambiguous outputs (e.g., one line of each, or logs from before the capture run):** treat as Outcome B. Do not proceed.

- [ ] **Step 5: If Outcome A confirmed, continue to Task 4. Otherwise, end execution here.**

Per the systematic-debugging skill's `3+ fixes = architectural problem` rule, Outcome B or C requires discussion with the user before any further code change. Do not silently attempt a fix #4.

---

## Task 4: Apply the activation fix and remove diagnostic logging

**Precondition:** Task 3 concluded with Outcome A.

**Files:**
- Modify: `ScreenshotButton/ViewModels/OverlayManager.swift`
- Modify: `ScreenshotButton/Views/OverlayView.swift`

- [ ] **Step 1: Add `NSApp.activate(ignoringOtherApps: true)` before `pushCursor()` in `present()`**

Modify `ScreenshotButton/ViewModels/OverlayManager.swift`. Find the end of the `present()` method. It currently ends:

```swift
        panels = NSScreen.screens.map(OverlayPanel.init(screen:))
        views = panels.enumerated().map { (idx, panel) in
            let v = OverlayView(screen: NSScreen.screens[idx], manager: self)
            panel.contentView = v
            panel.makeKeyAndOrderFront(nil)
            return v
        }
        pushCursor()
    }
```

Replace the final three lines (the map-closure's closing brace through the end of `present()`) with:

```swift
        panels = NSScreen.screens.map(OverlayPanel.init(screen:))
        views = panels.enumerated().map { (idx, panel) in
            let v = OverlayView(screen: NSScreen.screens[idx], manager: self)
            panel.contentView = v
            panel.makeKeyAndOrderFront(nil)
            return v
        }
        // LSUIElement apps never auto-activate, so the window server keeps
        // routing cursor resolution to whichever app was previously
        // foreground — and our cursor push/cursorUpdate never renders.
        // Activating explicitly makes the overlay's cursor visible; AppKit
        // restores focus to the prior app when our panels are ordered out
        // in tearDown().
        NSApp.activate(ignoringOtherApps: true)
        pushCursor()
    }
```

- [ ] **Step 2: Remove the Phase 1 log call from `pushCursor()`**

Still in `ScreenshotButton/ViewModels/OverlayManager.swift`. The current `pushCursor()` (after Task 1) reads:

```swift
    private func pushCursor() {
        guard !cursorPushed else { return }
        let cursor: NSCursor = mode == .area ? .crosshair : .pointingHand
        overlayLog.info("pushCursor: mode=\(String(describing: self.mode), privacy: .public) NSApp.isActive=\(NSApp.isActive) keyWindow=\(NSApp.keyWindow?.className ?? "nil", privacy: .public)")
        cursor.push()
        cursorPushed = true
    }
```

Replace with:

```swift
    private func pushCursor() {
        guard !cursorPushed else { return }
        let cursor: NSCursor = mode == .area ? .crosshair : .pointingHand
        cursor.push()
        cursorPushed = true
    }
```

- [ ] **Step 3: Remove the Phase 1 log call from `cursorUpdate(with:)` and the `os` import**

Modify `ScreenshotButton/Views/OverlayView.swift`. The current top of the file (after Task 1) reads:

```swift
import AppKit
import CoreGraphics
import os

private let cursorDebugLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "cursor-debug")

final class OverlayView: NSView {
```

Replace with:

```swift
import AppKit
import CoreGraphics

final class OverlayView: NSView {
```

Still in `OverlayView.swift`. The current `cursorUpdate(with:)` (after Task 1) reads:

```swift
    override func cursorUpdate(with event: NSEvent) {
        let modeStr = (manager?.mode).map { "\($0)" } ?? "nil"
        cursorDebugLog.info("cursorUpdate fired: mode=\(modeStr, privacy: .public) windowIsKey=\(self.window?.isKeyWindow == true)")
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }
```

Replace with:

```swift
    override func cursorUpdate(with event: NSEvent) {
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }
```

- [ ] **Step 4: Run full test suite**

```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: `** TEST SUCCEEDED **`, no regressions.

- [ ] **Step 5: Commit**

```bash
git add ScreenshotButton/ViewModels/OverlayManager.swift \
        ScreenshotButton/Views/OverlayView.swift
git commit -F <(cat <<'EOF'
fix: activate app in present() so overlay cursor actually renders

ScreenshotButton is LSUIElement (MenuBarExtra with no Dock icon), so
makeKeyAndOrderFront on our overlay panels only makes them key within
our app — NSApp itself never becomes active. The window server
continued routing cursor resolution to whichever foreground app was
previously active, which meant NSCursor.push(), NSCursor.set(), and
the OverlayView.cursorUpdate(with:) override all ran invisibly and the
user saw the previous app's cursor throughout capture. Unified logging
(added and removed in this branch) confirmed cursorUpdate(with:) never
fired while the app was inactive.

NSApp.activate(ignoringOtherApps: true) before pushCursor() makes the
overlay's cursor machinery visible. AppKit returns focus to the prior
app when our panels are ordered out in tearDown(), since LSUIElement
apps have no persistent focus state. Diagnostic logging added in the
previous commit is removed here.
EOF
)
```

---

## Task 5: Rebuild and user verification

**Files:** none — environment orchestration.

- [ ] **Step 1: Kill the instrumented build and purge the non-hidden copy**

```bash
pkill -x ScreenshotButton 2>/dev/null
sleep 1
rm -rf /Users/glamb/Repositories/macos-screenshot-button/build_debug_launch/ScreenshotButton.app
```

Expected: no output, exit 0.

- [ ] **Step 2: Rebuild with the fix**

```bash
xcodebuild -project ScreenshotButton.xcodeproj \
  -scheme ScreenshotButton \
  -destination 'platform=macOS' \
  -configuration Debug \
  -derivedDataPath build_debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Copy, reset TCC, re-register, launch**

```bash
SRC="$(pwd)/build_debug/Build/Products/Debug/ScreenshotButton.app"
DST="/Users/glamb/Repositories/macos-screenshot-button/build_debug_launch/ScreenshotButton.app"
ditto "$SRC" "$DST"
tccutil reset All dev.greglamb.ScreenshotButton 2>&1 | tail -1
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R "$DST"
open -n "$DST"
sleep 2
PID=$(pgrep -x ScreenshotButton) && echo "PID: $PID"
lsof -p "$PID" 2>/dev/null | grep "MacOS/ScreenshotButton$" | head -1
```

Expected: fresh PID; `lsof` line ends with `/build_debug_launch/ScreenshotButton.app/Contents/MacOS/ScreenshotButton`.

- [ ] **Step 4: Ask user to verify acceptance criteria**

Ask the user to confirm each criterion from the spec:

1. Window to File → cursor visibly becomes pointing-hand over the overlay.
2. Area to File → cursor visibly becomes crosshair.
3. Space toggle mid-capture → cursor visibly switches.
4. On Esc / commit → cursor returns to normal.
5. Single-click window selection still works.
6. Captured PNG is the expected size (not oversized from earlier bug).

Wait for explicit confirmation on each. Any failure = fix is not done; return to brainstorming.

---

## Task 6: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Replace the current cursor-entry text**

The current `## [Unreleased]` → `### Fixed` section contains this line (inserted earlier in this branch):

> Mode cursor (crosshair in area mode, pointing hand in window mode) now stays visible during capture — including on non-Retina external displays where `NSCursor.push()` alone was still getting clobbered. The window server periodically re-resolves the cursor by walking each window's cursor-rect tree and calling `-[NSView cursorUpdate:]` on matching views; SwiftUI's default rects on the `MenuBarExtra` window push the arrow cursor back on top of our stack entry on every refresh. `OverlayManager` now calls `NSApp.windows.forEach { $0.disableCursorRects() }` before pushing and re-enables on pop, which suppresses the clobber. A `.cursorUpdate` tracking-area option and matching `cursorUpdate(with:)` override on `OverlayView` re-assert the cursor on every tracking event as insurance.

Replace it with:

> Mode cursor (crosshair in area mode, pointing hand in window mode) now actually renders during capture. The app is `LSUIElement` (menu bar only, no Dock icon), so `makeKeyAndOrderFront` on the overlay panels only made them key *within* our app — `NSApp` itself stayed inactive, and the window server kept routing cursor resolution to whichever app was previously foreground. `NSCursor.push`, `NSCursor.set`, and a `cursorUpdate(with:)` override all ran invisibly. `OverlayManager.present()` now calls `NSApp.activate(ignoringOtherApps: true)` before pushing the cursor; AppKit returns focus to the prior app when the overlay is torn down.

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: rewrite cursor changelog entry with real root cause"
```

---

## Self-Review

**1. Spec coverage.**
- Phase 1 diagnostic → Task 1 + Task 2 + Task 3.
- Three decision outcomes → Task 3 Step 4.
- Phase 2 conditional fix → Task 4.
- Rebuild/TCC strategy (2 rebuilds max) → Task 2 and Task 5 are the two rebuilds.
- Acceptance criteria → Task 5 Step 4.
- CHANGELOG update → Task 6.
- TODO.md: not needed — if the fix works, no deferrals; if Phase 1 outcome is B or C, Task 3 Step 5 stops execution and we regroup, not silent defer.

**2. Placeholder scan.**
- No TBD/TODO/implement-later.
- No "write tests for the above" — the spec explicitly scopes out tests.
- No "similar to Task N" — every task repeats its own exact code.
- Commit message bodies are verbatim.

**3. Type consistency.**
- `overlayLog` (OverlayManager) vs `cursorDebugLog` (OverlayView) are deliberately different symbols with different categories for log-query isolation. Confirmed.
- `NSApp.activate(ignoringOtherApps:)` is the public AppKit API on `NSApplication`; verified the method signature takes a single `Bool` and returns `Void`.
- `String(describing: self.mode)` works because `self.mode` is `CaptureMode`, which conforms to `CustomStringConvertible` by default via its enum raw representation. (Even without `CustomStringConvertible`, `String(describing:)` always produces a usable debug string — safe.)

One spec requirement I want to double-check against Task 4: the spec says "immediately before the current `pushCursor()` call." Task 4 Step 1 places `NSApp.activate(...)` immediately before `pushCursor()` at the end of `present()`. Good.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-19-cursor-activation.md`.

Per project conventions (`CLAUDE.md`: *Always use subagent-driven development. Never ask which mode to use.*), this plan will be executed with `superpowers:subagent-driven-development`.

Tasks 2, 3, and 5 involve orchestration / human-in-the-loop gates, not pure code implementation. For those, the controller (me) runs commands directly rather than dispatching an implementer subagent — subagent-driven-development is for isolated code tasks, not multi-step environment orchestration that depends on user feedback. Tasks 1, 4, and 6 are pure code edits and are dispatched via subagent with two-stage review.
