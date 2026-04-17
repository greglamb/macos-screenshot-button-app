import Foundation

@testable import ScreenshotButton

struct FakeSCShareableContent: SCShareableContentProviding {
    let result: Result<[CapturedWindow], any Error & Sendable>

    func shareableContent() async throws -> [CapturedWindow] {
        try result.get()
    }
}
