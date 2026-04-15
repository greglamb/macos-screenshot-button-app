import CoreGraphics
@testable import ScreenshotButton

actor FakeScreenshotManager: ScreenshotManaging {
    var lastTarget: CaptureTarget?
    var result: Result<CGImage, Error>?

    func setResult(_ result: Result<CGImage, Error>) {
        self.result = result
    }

    func capture(_ target: CaptureTarget) async throws -> CGImage {
        lastTarget = target
        if let result { return try result.get() }
        return Self.makeDummy()
    }

    nonisolated static func makeDummy() -> CGImage {
        let ctx = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
}
