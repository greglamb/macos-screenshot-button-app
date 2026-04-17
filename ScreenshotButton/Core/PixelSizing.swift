import CoreGraphics

/// Converts point-space sizes to integer pixel dimensions for
/// `SCStreamConfiguration.width`/`.height`, which are in pixels. Pair with
/// `SCContentFilter.pointPixelScale` — 1.0 on non-Retina / HDMI, 2.0 on Retina.
enum PixelSizing {
    static func pixels(points: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        (Int(points.width * scale), Int(points.height * scale))
    }
}
