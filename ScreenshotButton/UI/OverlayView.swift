import AppKit
import CoreGraphics

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

    override func updateTrackingAreas() {
        trackingAreas.forEach { removeTrackingArea($0) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self, userInfo: nil
        )
        addTrackingArea(ta)
    }

    /// AppKit calls this when the mouse enters the tracking area (we set
    /// `.cursorUpdate` in `updateTrackingAreas`). Setting via `.set()` rather
    /// than `addCursorRect` works reliably on borderless `nonactivatingPanel`s
    /// at `.screenSaver` level, where the cursor-rect machinery is unreliable.
    override func cursorUpdate(with event: NSEvent) {
        currentCursor.set()
    }

    /// Called by `OverlayManager` after Space toggles the capture mode.
    /// Sets the cursor immediately so the user doesn't have to wiggle the mouse.
    func refreshCursor() {
        currentCursor.set()
    }

    private var currentCursor: NSCursor {
        switch manager?.mode {
        case .area:   return .crosshair
        case .window: return .pointingHand
        case .none:   return .arrow
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let screenPoint = screenPoint(for: event)
        manager?.didMove(to: screenPoint, on: self)
        // Belt-and-suspenders: borderless `nonactivatingPanel`s at high window
        // levels don't always trigger `cursorUpdate`. Setting on every mouseMoved
        // is cheap and guarantees the cursor reflects the current mode.
        currentCursor.set()
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
        case 53:  manager?.didPressEscape()           // Esc
        case 49:  manager?.didPressSpace()            // Space
        default:  super.keyDown(with: event)
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
