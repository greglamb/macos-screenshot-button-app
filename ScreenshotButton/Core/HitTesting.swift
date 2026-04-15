import CoreGraphics

enum HitTesting {
    /// `windows` must be in front-to-back z-order (index 0 is frontmost).
    static func topmost(at point: CGPoint, in windows: [CapturedWindow]) -> CapturedWindow? {
        windows.first { $0.frame.contains(point) }
    }
}
