import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum PNGEncoder {
    enum Failure: Error { case encodingFailed }

    static func encode(_ image: CGImage, dpi: CGFloat = 144) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw Failure.encodingFailed
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw Failure.encodingFailed
        }
        return data as Data
    }
}
