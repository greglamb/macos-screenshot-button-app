import Testing
import CoreGraphics
import ImageIO
@testable import ScreenshotButton

@Suite("PNG encoding")
struct PNGEncoderTests {
    @Test("Round-trips image dimensions through PNG")
    func pngEncodeRoundTripsDimensions() throws {
        let image = try #require(makeTestImage(width: 42, height: 17))
        let data = try PNGEncoder.encode(image)
        let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        #expect(decoded.width == 42)
        #expect(decoded.height == 17)
    }

    private func makeTestImage(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
