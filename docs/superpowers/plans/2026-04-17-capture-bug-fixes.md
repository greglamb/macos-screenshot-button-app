# Capture Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three capture-time bugs exposed when running on an external (non-Retina) HDMI monitor: oversized PNG output, double-click required for window selection, and cursor not changing to crosshair/pointing-hand on the external display.

**Architecture:**
- Fix 1 (oversize): introduce a tiny pure helper `PixelSizing.pixels(points:scale:)` in `Core/` and have `SCScreenshotManagerAdapter` use `filter.pointPixelScale` through it, replacing the hardcoded `* 2`. Helper is unit-tested; the adapter call site is integration-verified at runtime.
- Fix 2 (double-click): add `acceptsFirstMouse(for:)` override on `OverlayView` returning `true`. Without this, `nonactivatingPanel` swallows the first mouseDown.
- Fix 3 (cursor on HDMI): add `.cursorUpdate` to `OverlayView`'s tracking area and override `cursorUpdate(with:)` to re-`set()` the mode-appropriate cursor. Keep `OverlayManager.pushCursor/popCursor` as the initial baseline. The cursorUpdate re-assertion is what makes the cursor stick when it crosses a display boundary on nonactivating panels.

**Tech Stack:** Swift 6 strict concurrency, Swift Testing (`@Test`, `#expect`), AppKit (`NSView`, `NSCursor`, `NSTrackingArea`), ScreenCaptureKit (`SCContentFilter.pointPixelScale`, `SCStreamConfiguration`).

---

## File Structure

**New files:**
- `ScreenshotButton/Core/PixelSizing.swift` — pure scaling helper (point → pixel dimensions).
- `ScreenshotButtonTests/Core/PixelSizingTests.swift` — unit tests for the helper.
- `ScreenshotButtonTests/Views/OverlayViewTests.swift` — tests `acceptsFirstMouse` and the tracking-area options. (New `Views/` test dir — tests mirror source.)

**Modified files:**
- `ScreenshotButton/Services/SCScreenshotManagerAdapter.swift` — use `PixelSizing.pixels` with `filter.pointPixelScale`.
- `ScreenshotButton/Views/OverlayView.swift` — `acceptsFirstMouse` override; `.cursorUpdate` tracking option; `cursorUpdate(with:)` override that calls `NSCursor.set()` based on `manager?.mode`.
- `CHANGELOG.md` — user-facing fix notes under `[Unreleased]` / `### Fixed`.

---

## Task 1: Extract pixel-sizing helper

**Files:**
- Create: `ScreenshotButton/Core/PixelSizing.swift`
- Create: `ScreenshotButtonTests/Core/PixelSizingTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `ScreenshotButtonTests/Core/PixelSizingTests.swift`:

```swift
import CoreGraphics
import Testing

@testable import ScreenshotButton

@Suite("PixelSizing")
struct PixelSizingTests {
    @Test(
        "Multiplies point-size by scale to produce integer pixel dimensions",
        arguments: [
            (CGSize(width: 100, height: 50), CGFloat(2.0), 200, 100),  // Retina
            (CGSize(width: 1784, height: 1224), CGFloat(1.0), 1784, 1224),  // HDMI 1x
            (CGSize(width: 800, height: 600), CGFloat(1.5), 1200, 900),  // Fractional
            (CGSize(width: 0, height: 0), CGFloat(2.0), 0, 0),  // Zero size
        ])
    func pixelsFromPointsAndScale(
        points: CGSize, scale: CGFloat, expectedW: Int, expectedH: Int
    ) {
        let (w, h) = PixelSizing.pixels(points: points, scale: scale)
        #expect(w == expectedW)
        #expect(h == expectedH)
    }

    @Test("Truncates toward zero for non-integer pixel results")
    func truncatesFractionalPixels() {
        let (w, h) = PixelSizing.pixels(
            points: CGSize(width: 10.9, height: 20.4),
            scale: 1.0
        )
        #expect(w == 10)
        #expect(h == 20)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "error:|PixelSizing" | head -5
```

Expected: compile error (`cannot find 'PixelSizing' in scope`).

- [ ] **Step 3: Create the helper**

Create `ScreenshotButton/Core/PixelSizing.swift`:

```swift
import CoreGraphics

/// Converts point-space sizes to integer pixel dimensions for
/// `SCStreamConfiguration.width`/`.height`, which are in pixels. Pair with
/// `SCContentFilter.pointPixelScale` — 1.0 on non-Retina / HDMI, 2.0 on Retina.
enum PixelSizing {
    static func pixels(points: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        (Int(points.width * scale), Int(points.height * scale))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Regenerate Xcode project**

Run:
```bash
xcodegen generate
```

New source files under `ScreenshotButton/` and `ScreenshotButtonTests/` are auto-picked up by the globbed `sources:` entries in `Project.yml`, but regenerating ensures the committed `.xcodeproj` stays in sync with disk.

- [ ] **Step 6: Commit**

```bash
git add ScreenshotButton/Core/PixelSizing.swift \
        ScreenshotButtonTests/Core/PixelSizingTests.swift \
        ScreenshotButton.xcodeproj/project.pbxproj
git commit -m "feat: add PixelSizing helper for point→pixel scaling"
```

---

## Task 2: Use pointPixelScale in the SCK adapter

**Files:**
- Modify: `ScreenshotButton/Services/SCScreenshotManagerAdapter.swift`

No test changes — this is an integration path against SCK and is manually verified by the user at runtime. Task 1 gave us unit coverage for the math.

- [ ] **Step 1: Replace hardcoded `* 2` with `filter.pointPixelScale`**

Replace the current adapter body. New contents of `ScreenshotButton/Services/SCScreenshotManagerAdapter.swift`:

```swift
import CoreGraphics
import ScreenCaptureKit

struct SCScreenshotManagerAdapter: ScreenshotManaging {
    func capture(_ target: CaptureTarget) async throws -> CGImage {
        switch target {
        case .window(let id):
            let content = try await SCShareableContent.current
            guard let scWindow = content.windows.first(where: { $0.windowID == id }) else {
                throw CaptureError.windowGone
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let (w, h) = PixelSizing.pixels(
                points: scWindow.frame.size,
                scale: CGFloat(filter.pointPixelScale)
            )
            config.width = w
            config.height = h
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        case .area(let rect, let displayID):
            let content = try await SCShareableContent.current
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.displayGone
            }
            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = rect
            let (w, h) = PixelSizing.pixels(
                points: rect.size,
                scale: CGFloat(filter.pointPixelScale)
            )
            config.width = w
            config.height = h
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        }
    }
}

enum CaptureError: Error, Equatable {
    case windowGone
    case displayGone
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild build -project ScreenshotButton.xcodeproj -scheme ScreenshotButton -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run full test suite**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: all tests still pass.

- [ ] **Step 4: Commit**

```bash
git add ScreenshotButton/Services/SCScreenshotManagerAdapter.swift
git commit -m "fix: honor SCContentFilter.pointPixelScale for capture dimensions

On non-Retina (e.g. HDMI) displays pointPixelScale is 1.0, so hardcoding
* 2 overshot SCStreamConfiguration.width/height by 2x each axis. The
filter then only drew its native pixel area (the actual window content)
in the top-left quadrant of the 4x-too-large canvas, producing a window
screenshot stuck in the corner of an empty page.

Use filter.pointPixelScale via the new PixelSizing helper so output
matches the filter's native pixel area on every display scale."
```

---

## Task 3: acceptsFirstMouse on OverlayView

**Files:**
- Modify: `ScreenshotButton/Views/OverlayView.swift`
- Create: `ScreenshotButtonTests/Views/OverlayViewTests.swift`

- [ ] **Step 1: Write the failing test**

Create `ScreenshotButtonTests/Views/OverlayViewTests.swift`:

```swift
import AppKit
import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("OverlayView")
struct OverlayViewTests {
    @Test("acceptsFirstMouse(for:) returns true so a single click registers on nonactivating panels")
    func acceptsFirstMouseIsTrue() throws {
        let screen = try #require(NSScreen.main)
        let view = OverlayView(screen: screen, manager: Self.makeManager())
        #expect(view.acceptsFirstMouse(for: nil) == true)
    }

    private static func makeManager() -> OverlayManager {
        let controller = CaptureController(
            enumerator: FakeSCShareableContent(result: .success([])),
            capturer: Capturer(manager: FakeScreenshotManager()),
            fileSink: FileSink(
                writer: FakeFileWriter(),
                opener: FakePreviewOpener(),
                nowProvider: { Date(timeIntervalSince1970: 0) },
                tempDirectoryProvider: { URL(fileURLWithPath: NSTemporaryDirectory()) }
            ),
            clipboardSink: ClipboardSink(pasteboard: FakePasteboard())
        )
        return OverlayManager(controller: controller, notifier: FakeNotifying())
    }
}
```

- [ ] **Step 2: Regenerate project so the new Views/ test dir is included**

Run:
```bash
xcodegen generate
```

- [ ] **Step 3: Run test to verify it fails**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' -only-testing:ScreenshotButtonTests/OverlayView 2>&1 | grep -E "failed|error:|acceptsFirstMouse" | head -5
```

Expected: failure — `NSView`'s default implementation returns `false`.

- [ ] **Step 4: Add the override**

Modify `ScreenshotButton/Views/OverlayView.swift`. Add this override immediately after the existing `becomeFirstResponder` override (around line 23):

```swift
    // `nonactivatingPanel` doesn't receive the first mouseDown by default —
    // the first click gets consumed as a window-key handoff. Returning true
    // here makes single-click window selection register on the first try.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' -only-testing:ScreenshotButtonTests/OverlayView 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Run full suite to confirm nothing regressed**

```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: all suites pass.

- [ ] **Step 7: Commit**

```bash
git add ScreenshotButton/Views/OverlayView.swift \
        ScreenshotButtonTests/Views/OverlayViewTests.swift \
        ScreenshotButton.xcodeproj/project.pbxproj
git commit -m "fix: accept first mouse in OverlayView so single click selects

nonactivatingPanel swallows the first mouseDown by default — it's
consumed as a window-key transition and only the second click reaches
the view. Overriding acceptsFirstMouse(for:) lets the first click fire
mouseDown directly, restoring single-click window selection."
```

---

## Task 4: Re-assert cursor via cursorUpdate

**Files:**
- Modify: `ScreenshotButton/Views/OverlayView.swift`
- Modify: `ScreenshotButtonTests/Views/OverlayViewTests.swift`

- [ ] **Step 1: Add the failing test for the tracking-area option**

Append to `ScreenshotButtonTests/Views/OverlayViewTests.swift` (inside the existing `OverlayViewTests` struct):

```swift
    @Test(
        "Tracking area includes .cursorUpdate so cursorUpdate(with:) is called as the cursor moves — needed to keep the mode-cursor sticky on nonactivating panels across displays")
    func trackingAreaIncludesCursorUpdate() throws {
        let screen = try #require(NSScreen.main)
        let view = OverlayView(screen: screen, manager: Self.makeManager())
        view.updateTrackingAreas()
        let hasCursorUpdate = view.trackingAreas.contains { $0.options.contains(.cursorUpdate) }
        #expect(hasCursorUpdate == true)
    }
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' -only-testing:ScreenshotButtonTests/OverlayView/trackingAreaIncludesCursorUpdate 2>&1 | grep -E "failed|error:|cursorUpdate" | head -5
```

Expected: `#expect(hasCursorUpdate == true)` fails — current tracking options are `[.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect]`.

- [ ] **Step 3: Add `.cursorUpdate` to the tracking area and override `cursorUpdate(with:)`**

Modify `ScreenshotButton/Views/OverlayView.swift`.

First, extend the tracking-area options. Replace the body of `updateTrackingAreas()` (currently lines 25-33) with:

```swift
    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
    }
```

Then add a `cursorUpdate(with:)` override. Place it immediately after `mouseMoved(with:)`:

```swift
    // Window server can reset the cursor for borderless nonactivatingPanels
    // at .screenSaver level, especially across display boundaries. Re-setting
    // the mode cursor from cursorUpdate keeps it sticky — this event fires
    // whenever AppKit thinks the cursor needs refreshing over our tracking
    // area.
    override func cursorUpdate(with event: NSEvent) {
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }
```

Update the explanatory comment block at lines 35-38 (which currently describes push/pop ownership) to:

```swift
    // Initial cursor is set by `OverlayManager.pushCursor()` when the overlay
    // is presented; `cursorUpdate(with:)` re-asserts it on every tracking-area
    // refresh so the window server can't clobber it on nonactivatingPanels or
    // when the cursor crosses onto a secondary display.
```

- [ ] **Step 4: Run the full OverlayView suite to verify it passes**

Run:
```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' -only-testing:ScreenshotButtonTests/OverlayView 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: both OverlayView tests pass.

- [ ] **Step 5: Run full suite**

```bash
xcodebuild test -project ScreenshotButton.xcodeproj -scheme ScreenshotButtonTests -destination 'platform=macOS' 2>&1 | grep -E "\*\* TEST|Executed [0-9]+ test" | tail -3
```

Expected: all suites pass.

- [ ] **Step 6: Commit**

```bash
git add ScreenshotButton/Views/OverlayView.swift \
        ScreenshotButtonTests/Views/OverlayViewTests.swift
git commit -m "fix: re-assert cursor from cursorUpdate for secondary displays

push/pop alone set the cursor once at overlay-present time; the window
server can reset it on borderless nonactivatingPanels at .screenSaver
level, especially when the cursor crosses onto a non-Retina secondary
display where the primary-display push didn't take. Adding
.cursorUpdate to the tracking area and re-setting the mode cursor from
cursorUpdate(with:) makes the mode cursor (crosshair / pointing hand)
sticky on every display."
```

---

## Task 5: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add entries under `[Unreleased]` → `### Fixed`**

Add these bullets to the existing `## [Unreleased]` → `### Fixed` section (create the `### Fixed` subsection if not present):

```markdown
- Window captures no longer produce an oversized PNG on non-Retina (e.g. HDMI) external monitors. The capture now uses `SCContentFilter.pointPixelScale` rather than a hardcoded `* 2`, so output matches the filter's native pixel area on every display scale.
- Single-click window selection now works reliably. The overlay panel is `nonactivatingPanel`, which by default swallows the first mouseDown as a window-key handoff; overriding `acceptsFirstMouse(for:)` on `OverlayView` routes the first click straight to the hit-test.
- Mode cursor (crosshair in area mode, pointing hand in window mode) now stays visible when the overlay spans a secondary display. `NSCursor.push()` alone gets reset by the window server on borderless nonactivating panels; adding `.cursorUpdate` to the tracking area and re-setting the cursor from `cursorUpdate(with:)` keeps it sticky.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog entries for HDMI-display capture fixes"
```

---

## Self-Review

- **Spec coverage:** Three bugs → three fixes + helper + changelog. Covered.
- **Placeholders:** None — every step has exact code and commands.
- **Type consistency:** `PixelSizing.pixels(points:scale:)` returns `(width: Int, height: Int)` — consumers destructure with `let (w, h)`. `OverlayView.cursorUpdate(with:)` and `acceptsFirstMouse(for:)` match AppKit signatures. `manager?.mode` returns `CaptureMode`; `.area` / `.window` are its only cases.
- **Test seam for Fix 1:** The adapter itself isn't unit-testable without mocking SCK, but `PixelSizing.pixels` carries the scaling invariant. Runtime verification happens in Task 6 with the user on their HDMI + Retina setup.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-17-capture-bug-fixes.md`. Per CLAUDE.md (`Always use subagent-driven development. Never ask which mode to use.`), proceeding with **Subagent-Driven** execution via `superpowers:subagent-driven-development`.
