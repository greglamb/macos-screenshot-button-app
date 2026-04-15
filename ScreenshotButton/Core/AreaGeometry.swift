import CoreGraphics

enum AreaGeometry {
    /// A drag smaller than this on either axis is treated as an accidental click.
    static let minSide: CGFloat = 5

    static func rectangle(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func isCancel(_ rect: CGRect) -> Bool {
        rect.width < minSide || rect.height < minSide
    }
}
