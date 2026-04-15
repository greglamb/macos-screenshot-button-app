import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class OverlayManager {
    let controller: CaptureController
    let notifier: Notifier
    private(set) var panels: [OverlayPanel] = []
    private var views: [OverlayView] = []
    private var windows: [CapturedWindow] = []
    private var presentTask: Task<Void, Never>?
    private var deliveryTask: Task<Void, Never>?

    var mode: CaptureMode { controller.session.mode }

    init(controller: CaptureController, notifier: Notifier) {
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
        windows = fetched
        panels = NSScreen.screens.map(OverlayPanel.init(screen:))
        views = panels.enumerated().map { (idx, panel) in
            let v = OverlayView(screen: NSScreen.screens[idx])
            v.manager = self
            panel.contentView = v
            panel.makeKeyAndOrderFront(nil)
            return v
        }
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
        let localRect = CGRect(
            x: rect.origin.x - view.screen.frame.origin.x,
            y: rect.origin.y - view.screen.frame.origin.y,
            width: rect.width, height: rect.height
        )
        tearDown()
        deliveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.controller.commitArea(localRect, displayID: displayID)
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
    }

    /// User-initiated cancel (Esc, click-empty-area, etc.). Tears down UI,
    /// cancels in-flight tasks, and resets the session.
    func dismiss() {
        tearDown()
        presentTask?.cancel(); presentTask = nil
        deliveryTask?.cancel(); deliveryTask = nil
        controller.cancel()
    }

    private func tearDown() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        views.removeAll()
        windows.removeAll()
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
