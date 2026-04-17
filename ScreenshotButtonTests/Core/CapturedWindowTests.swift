import CoreGraphics
import Testing

@testable import ScreenshotButton

@Suite("CapturedWindow")
struct CapturedWindowTests {
    @Test("Identity is stable across frame / title changes")
    func capturedWindowHasStableIdentity() {
        let a = CapturedWindow(id: 42, frame: .zero, title: "A", ownerName: "X")
        let b = CapturedWindow(id: 42, frame: .init(x: 9, y: 9, width: 9, height: 9), title: "B", ownerName: "Y")
        #expect(a.id == b.id)
    }

    @Test("Equality compares all fields")
    func capturedWindowEquatableByAllFields() {
        let a = CapturedWindow(id: 1, frame: .zero, title: "T", ownerName: "O")
        let b = CapturedWindow(id: 1, frame: .zero, title: "T", ownerName: "O")
        let c = CapturedWindow(id: 1, frame: .zero, title: "T", ownerName: "Q")
        #expect(a == b)
        #expect(a != c)
    }
}
