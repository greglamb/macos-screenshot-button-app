import AppKit
import CoreGraphics
import os

private let cursorDebugLog = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "cursor-debug")

final class OverlayView: NSView {
    weak var manager: OverlayManager?
    let screen: NSScreen

    private var dragStart: CGPoint?
    private var dragEnd: CGPoint?
    private var hoveredFrame: CGRect?

    init(screen: NSScreen, manager: OverlayManager) {
        self.screen = screen
        self.manager = manager
        super.init(frame: screen.frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    // `nonactivatingPanel` doesn't receive the first mouseDown by default —
    // the first click gets consumed as a window-key handoff. Returning true
    // here makes single-click window selection register on the first try.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
    }

    // The window server periodically re-resolves the cursor by walking
    // registered cursor rects on the view under the cursor. Without a cursor
    // rect it resolves to default arrow — clobbering our `cursor.set()` from
    // `cursorUpdate(with:)`. Registering a cursor rect covering the entire
    // view installs our mode cursor in that resolution pass, so it survives
    // between `cursorUpdate` events. `OverlayManager` calls
    // `invalidateCursorRects(for:)` on mode toggle so this reflects the
    // current mode.
    override func resetCursorRects() {
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursorDebugLog.info("resetCursorRects fired: mode=\(String(describing: self.manager?.mode), privacy: .public)")
        addCursorRect(bounds, cursor: cursor)
    }

    override func mouseMoved(with event: NSEvent) {
        let screenPoint = screenPoint(for: event)
        manager?.didMove(to: screenPoint, on: self)
    }

    // Window server can reset the cursor for borderless nonactivatingPanels
    // at .screenSaver level, especially across display boundaries. Re-setting
    // the mode cursor from cursorUpdate keeps it sticky — this event fires
    // whenever AppKit thinks the cursor needs refreshing over our tracking
    // area.
    override func cursorUpdate(with event: NSEvent) {
        let modeStr = (manager?.mode).map { "\($0)" } ?? "nil"
        cursorDebugLog.info("cursorUpdate fired: mode=\(modeStr, privacy: .public) windowIsKey=\(self.window?.isKeyWindow == true)")
        let cursor: NSCursor = (manager?.mode == .area) ? .crosshair : .pointingHand
        cursor.set()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = screenPoint(for: event)
        dragEnd = dragStart
        if manager?.mode == .window {
            manager?.didClickWindow(at: screenPoint(for: event), on: self)
        }
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        dragEnd = screenPoint(for: event)
        setNeedsDisplay(bounds)
    }

    override func mouseUp(with event: NSEvent) {
        if manager?.mode == .area, let start = dragStart, let end = dragEnd {
            manager?.didCompleteArea(from: start, to: end, on: self)
        }
        dragStart = nil
        dragEnd = nil
        setNeedsDisplay(bounds)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: manager?.didPressEscape()  // Esc
        case 49: manager?.didPressSpace()  // Space
        default: super.keyDown(with: event)
        }
    }

    func updateHoveredFrame(_ frame: CGRect?) {
        hoveredFrame = frame
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let manager else { return }

        switch manager.mode {
        case .window:
            if let frame = hoveredFrame {
                let local = convertFromScreen(frame)
                let path = NSBezierPath(roundedRect: local, xRadius: 4, yRadius: 4)
                NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
                path.fill()
                NSColor.controlAccentColor.setStroke()
                path.lineWidth = 2
                path.stroke()
            }
        case .area:
            if let start = dragStart, let end = dragEnd {
                let rect = AreaGeometry.rectangle(from: start, to: end)
                let local = convertFromScreen(rect)
                NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
                local.fill()
                NSColor.controlAccentColor.setStroke()
                let path = NSBezierPath(rect: local)
                path.lineWidth = 1
                path.stroke()
            }
        }
    }

    private func screenPoint(for event: NSEvent) -> CGPoint {
        let windowPoint = event.locationInWindow
        let viewPoint = convert(windowPoint, from: nil)
        return convertToScreen(viewPoint)
    }

    private func convertToScreen(_ point: CGPoint) -> CGPoint {
        CGPoint(x: screen.frame.origin.x + point.x, y: screen.frame.origin.y + point.y)
    }

    private func convertFromScreen(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x - screen.frame.origin.x,
            y: rect.origin.y - screen.frame.origin.y,
            width: rect.width, height: rect.height
        )
    }
}
