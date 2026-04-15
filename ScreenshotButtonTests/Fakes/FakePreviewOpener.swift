import Foundation
@testable import ScreenshotButton

@MainActor
final class FakePreviewOpener: PreviewOpening {
    var openedURL: URL?

    nonisolated init() {}

    func open(_ url: URL) async throws {
        openedURL = url
    }
}
