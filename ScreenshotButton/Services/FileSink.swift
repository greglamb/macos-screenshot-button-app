import Foundation
import CoreGraphics

@MainActor
struct FileSink {
    static let folderName = "ScreenshotButton"

    let writer: any FileWriting
    let opener: any PreviewOpening
    let nowProvider: () -> Date
    let tempDirectoryProvider: () -> URL

    init(
        writer: any FileWriting = SystemFileWriter(),
        opener: any PreviewOpening = SystemPreviewOpener(),
        nowProvider: @escaping () -> Date = Date.init,
        tempDirectoryProvider: @escaping () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    ) {
        self.writer = writer
        self.opener = opener
        self.nowProvider = nowProvider
        self.tempDirectoryProvider = tempDirectoryProvider
    }

    @discardableResult
    func deliver(_ image: CGImage) async throws -> URL {
        let folder = tempDirectoryProvider().appendingPathComponent(Self.folderName, isDirectory: true)
        try writer.createDirectory(at: folder)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = .current
        let url = folder.appendingPathComponent("ScreenshotButton-\(formatter.string(from: nowProvider())).png")

        let data = try PNGEncoder.encode(image)
        try writer.write(data, to: url)
        try await opener.open(url)
        return url
    }
}
