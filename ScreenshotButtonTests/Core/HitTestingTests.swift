import Testing
import CoreGraphics
@testable import ScreenshotButton

@Suite("HitTesting")
struct HitTestingTests {
    private func w(_ id: CGWindowID, _ r: CGRect) -> CapturedWindow {
        CapturedWindow(id: id, frame: r, title: nil, ownerName: nil)
    }

    @Test("Empty list returns nil")
    func topmostReturnsNilForEmptyList() {
        #expect(HitTesting.topmost(at: .zero, in: []) == nil)
    }

    @Test("Point outside every frame returns nil")
    func topmostReturnsNilWhenNoneContainPoint() {
        let ws = [w(1, CGRect(x: 0, y: 0, width: 10, height: 10))]
        #expect(HitTesting.topmost(at: CGPoint(x: 100, y: 100), in: ws) == nil)
    }

    @Test("Returns frontmost window containing the point (front-to-back z-order)")
    func topmostReturnsFrontmostContainingPoint() {
        let ws = [
            w(1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            w(2, CGRect(x: 0, y: 0, width: 200, height: 200)),
        ]
        #expect(HitTesting.topmost(at: CGPoint(x: 50, y: 50), in: ws)?.id == 1)
        #expect(HitTesting.topmost(at: CGPoint(x: 150, y: 150), in: ws)?.id == 2)
    }
}
