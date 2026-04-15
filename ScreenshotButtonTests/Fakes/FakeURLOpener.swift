import Foundation
@testable import ScreenshotButton

@MainActor
final class FakeURLOpener: URLOpening {
    var openedURLs: [URL] = []
    func open(_ url: URL) {
        openedURLs.append(url)
    }
}
