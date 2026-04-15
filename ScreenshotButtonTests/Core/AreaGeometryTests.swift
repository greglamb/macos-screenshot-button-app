import Testing
import CoreGraphics
@testable import ScreenshotButton

struct DragPair: Sendable, CustomStringConvertible {
    let start: CGPoint
    let end: CGPoint
    let expected: CGRect
    var description: String { "\(start)→\(end)" }
}

struct CancelCase: Sendable, CustomStringConvertible {
    let rect: CGRect
    let isCancel: Bool
    var description: String { "\(rect)" }
}

@Suite("AreaGeometry")
struct AreaGeometryTests {
    @Test("Rectangle normalizes regardless of drag direction",
          arguments: [
            DragPair(start: .init(x: 0, y: 0),   end: .init(x: 10, y: 10), expected: .init(x: 0, y: 0, width: 10, height: 10)),
            DragPair(start: .init(x: 10, y: 10), end: .init(x: 0,  y: 0),  expected: .init(x: 0, y: 0, width: 10, height: 10)),
            DragPair(start: .init(x: 5,  y: 20), end: .init(x: 25, y: 0),  expected: .init(x: 5, y: 0, width: 20, height: 20)),
            DragPair(start: .init(x: 3,  y: 3),  end: .init(x: 3,  y: 3),  expected: .init(x: 3, y: 3, width: 0,  height: 0)),
          ])
    func rectangleNormalizes(_ drag: DragPair) {
        #expect(AreaGeometry.rectangle(from: drag.start, to: drag.end) == drag.expected)
    }

    @Test("Drags below the 5pt threshold are treated as cancel",
          arguments: [
            CancelCase(rect: .init(x: 0, y: 0, width: 0,   height: 0),   isCancel: true),
            CancelCase(rect: .init(x: 0, y: 0, width: 4,   height: 4),   isCancel: true),
            CancelCase(rect: .init(x: 0, y: 0, width: 5,   height: 5),   isCancel: false),
            CancelCase(rect: .init(x: 0, y: 0, width: 100, height: 100), isCancel: false),
          ])
    func cancelThreshold(_ c: CancelCase) {
        #expect(AreaGeometry.isCancel(c.rect) == c.isCancel)
    }
}
