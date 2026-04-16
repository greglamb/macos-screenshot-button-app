import CoreGraphics

/// Conversions between AppKit's Cocoa coordinate space (bottom-left origin)
/// and Quartz/CoreGraphics coordinate space (top-left origin).
///
/// `NSEvent.locationInWindow`, `NSScreen.frame`, and any `convert(...)` on an
/// `NSView` produce Cocoa coordinates. `SCWindow.frame`, `CGWindowListCopyWindowInfo`,
/// `SCStreamConfiguration.sourceRect`, and most CoreGraphics APIs use Quartz
/// coordinates. The two spaces share X but flip Y — mixing them silently
/// matches the wrong point/rect.
///
/// **Global vs display-local:** the global Quartz origin is the top-left of the
/// **primary** display (the one whose Cocoa origin is `(0, 0)`). For display-local
/// conversions (e.g., `SCStreamConfiguration.sourceRect`), use the *containing
/// display's* height, not the primary's.
enum ScreenCoordinates {

    /// Flip a global rect between Cocoa and Quartz spaces.
    /// Involutive — applying twice with the same `referenceHeight` returns the original.
    static func flipY(rect: CGRect, referenceHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: referenceHeight - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    /// Flip a single point between Cocoa and Quartz spaces.
    static func flipY(point: CGPoint, referenceHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: referenceHeight - point.y)
    }
}
