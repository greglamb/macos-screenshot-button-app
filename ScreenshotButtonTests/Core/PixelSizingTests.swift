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
