import Testing
import CoreGraphics
@testable import ScreenshotButton

@Suite("ScreenCoordinates")
struct ScreenCoordinatesTests {

    @Test("flipY(rect:) inverts Y around referenceHeight, preserves X/width/height")
    func flipRect() {
        // A window at top-left of a 1000-tall display in Quartz is at
        // (0, 0, 100, 50). In Cocoa (bottom-left origin) the same window is
        // at the top of the display, so its bottom edge is 950 from the bottom.
        let quartz = CGRect(x: 10, y: 0, width: 100, height: 50)
        let cocoa = ScreenCoordinates.flipY(rect: quartz, referenceHeight: 1000)
        #expect(cocoa == CGRect(x: 10, y: 950, width: 100, height: 50))
    }

    @Test("flipY(rect:) is involutive")
    func flipRectInvolutive() {
        let original = CGRect(x: 42, y: 137, width: 250, height: 400)
        let once = ScreenCoordinates.flipY(rect: original, referenceHeight: 1080)
        let twice = ScreenCoordinates.flipY(rect: once, referenceHeight: 1080)
        #expect(twice == original)
    }

    @Test("flipY(point:) inverts Y, preserves X")
    func flipPoint() {
        let cocoa = CGPoint(x: 42, y: 100)
        let quartz = ScreenCoordinates.flipY(point: cocoa, referenceHeight: 800)
        #expect(quartz == CGPoint(x: 42, y: 700))
    }

    @Test("flipY(point:) is involutive")
    func flipPointInvolutive() {
        let original = CGPoint(x: 99, y: 77)
        let once = ScreenCoordinates.flipY(point: original, referenceHeight: 1234)
        let twice = ScreenCoordinates.flipY(point: once, referenceHeight: 1234)
        #expect(twice == original)
    }
}
