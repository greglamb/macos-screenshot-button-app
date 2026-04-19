import AppKit
import CoreGraphics
import ScreenCaptureKit
import os

private let overlayLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "overlay")

@MainActor
final class OverlayManager {
    let controller: CaptureController
    let notifier: any Notifying
    private(set) var panels: [OverlayPanel] = []
    private var views: [OverlayView] = []
    private var windows: [CapturedWindow] = []
    private var presentTask: Task<Void, Never>?
    private var deliveryTask: Task<Void, Never>?
    private var cursorPushed = false

    var mode: CaptureMode { controller.session.mode }

    init(controller: CaptureController, notifier: any Notifying) {
        self.controller = controller
        self.notifier = notifier
    }

    /// Begins a capture session: starts the controller, presents per-screen
    /// overlays, and enumerates windows. Cancellable via `dismiss()`.
    func begin(mode: CaptureMode, sink: SinkKind) {
        guard controller.session.state == .idle else { return }
        controller.start(mode: mode, sink: sink)
        presentTask = Task { [weak self] in
            await self?.present()
        }
    }

    private func present() async {
        let fetched = await controller.enumerateWindowsOrHandle(notifier: notifier) { [notifier] in
            notifier.postPermissionDenied()
        }
        // Re-check state — user may have hit Esc on the menu while we awaited.
        guard controller.session.state == .capturing, let fetched else {
            tearDown()
            controller.cancel()
            return
        }
        // SCK returns frames in Quartz coords (top-left origin). The rest of
        // the app uses Cocoa (bottom-left origin from the primary display).
        // Flip Y once here so hit-testing, highlight drawing, and area rects
        // all live in the same space.
        let primaryHeight = primaryDisplayHeight()
        windows = fetched.map { w in
            CapturedWindow(
                id: w.id,
                frame: ScreenCoordinates.flipY(rect: w.frame, referenceHeight: primaryHeight),
                title: w.title,
                ownerName: w.ownerName
            )
        }
        panels = NSScreen.screens.map(OverlayPanel.init(screen:))
        views = panels.enumerated().map { (idx, panel) in
            let v = OverlayView(screen: NSScreen.screens[idx], manager: self)
            panel.contentView = v
            panel.makeKeyAndOrderFront(nil)
            return v
        }
        pushCursor()
    }

    func didMove(to point: CGPoint, on view: OverlayView) {
        guard mode == .window else {
            views.forEach { $0.updateHoveredFrame(nil) }
            return
        }
        let topmost = HitTesting.topmost(at: point, in: windows)
        views.forEach { $0.updateHoveredFrame(topmost?.frame) }
    }

    func didClickWindow(at point: CGPoint, on view: OverlayView) {
        guard let target = HitTesting.topmost(at: point, in: windows) else {
            dismiss()
            return
        }
        tearDown()
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.controller.commitWindow(target)
            } catch is CancellationError {
                self.controller.cancel()
            } catch let error as SCStreamError where error.code == .userDeclined {
                self.notifier.postPermissionDenied()
                self.controller.cancel()
            } catch {
                self.notifier.post(title: "Capture failed", body: "Please try again.")
                self.controller.cancel()
            }
        }
    }

    func didCompleteArea(from start: CGPoint, to end: CGPoint, on view: OverlayView) {
        let rect = AreaGeometry.rectangle(from: start, to: end)
        if AreaGeometry.isCancel(rect) {
            dismiss()
            return
        }
        let displayID = view.screen.displayID
        // Local Cocoa rect (bottom-left origin within the screen).
        let localCocoa = CGRect(
            x: rect.origin.x - view.screen.frame.origin.x,
            y: rect.origin.y - view.screen.frame.origin.y,
            width: rect.width, height: rect.height
        )
        // SCStreamConfiguration.sourceRect expects display-local Quartz coords
        // (top-left origin). Flip Y around *this display's* height.
        let localQuartz = ScreenCoordinates.flipY(
            rect: localCocoa,
            referenceHeight: view.screen.frame.height
        )
        tearDown()
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.controller.commitArea(localQuartz, displayID: displayID)
            } catch is CancellationError {
                self.controller.cancel()
            } catch let error as SCStreamError where error.code == .userDeclined {
                self.notifier.postPermissionDenied()
                self.controller.cancel()
            } catch {
                self.notifier.post(title: "Capture failed", body: "Please try again.")
                self.controller.cancel()
            }
        }
    }

    func didPressEscape() {
        dismiss()
    }

    func didPressSpace() {
        controller.session.toggle()
        views.forEach { $0.updateHoveredFrame(nil) }
        views.forEach { $0.setNeedsDisplay($0.bounds) }
        // Replace the pushed cursor so it matches the new mode.
        popCursor()
        pushCursor()
    }

    /// User-initiated cancel (Esc, click-empty-area, etc.). Tears down UI,
    /// cancels in-flight tasks, and resets the session.
    func dismiss() {
        tearDown()
        presentTask?.cancel()
        presentTask = nil
        deliveryTask?.cancel()
        deliveryTask = nil
        controller.cancel()
    }

    private func tearDown() {
        popCursor()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        views.removeAll()
        windows.removeAll()
    }

    /// Push the mode-appropriate cursor onto the global cursor stack. The
    /// window server respects the stack across borderless overlay panels
    /// where `addCursorRect`/`NSCursor.set()` get clobbered.
    private func pushCursor() {
        guard !cursorPushed else { return }
        let cursor: NSCursor = mode == .area ? .crosshair : .pointingHand
        overlayLog.info("pushCursor: mode=\(String(describing: self.mode), privacy: .public) NSApp.isActive=\(NSApp.isActive) keyWindow=\(NSApp.keyWindow?.className ?? "nil", privacy: .public)")
        cursor.push()
        cursorPushed = true
    }

    private func popCursor() {
        guard cursorPushed else { return }
        NSCursor.pop()
        cursorPushed = false
    }
}

extension NSScreen {
    fileprivate var displayID: CGDirectDisplayID {
        if let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.uint32Value
        }
        overlayLog.error("NSScreen missing NSScreenNumber; falling back to CGMainDisplayID()")
        return CGMainDisplayID()
    }
}

/// Height of the primary display (the one whose Cocoa origin is `(0, 0)`).
/// Used to flip global Quartz <-> Cocoa Y. Falls back to the main display's
/// pixel height if no primary is found, which on a single-display setup is
/// the same value.
@MainActor
private func primaryDisplayHeight() -> CGFloat {
    if let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
        return primary.frame.height
    }
    overlayLog.error("No primary NSScreen at origin (0,0); falling back to main display height")
    return NSScreen.main?.frame.height ?? 0
}
