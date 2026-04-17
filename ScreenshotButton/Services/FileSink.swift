import CoreGraphics
import Foundation

@MainActor
struct FileSink {
    static let folderName = "ScreenshotButton"

    // DateFormatter (not Date.FormatStyle) is intentional here: the
    // filename-safe `yyyy-MM-dd-HH-mm-ss` pattern with dash separators
    // isn't cleanly expressible via FormatStyle (default separators
    // include `/` and `:`). Cached as a static to avoid allocating per
    // call; `en_US_POSIX` locks the digits to ASCII regardless of the
    // user's locale.
    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

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

        let url = folder.appendingPathComponent(
            "ScreenshotButton-\(Self.filenameFormatter.string(from: nowProvider())).png")

        let data = try PNGEncoder.encode(image)
        try writer.write(data, to: url)
        try await opener.open(url)
        return url
    }
}
