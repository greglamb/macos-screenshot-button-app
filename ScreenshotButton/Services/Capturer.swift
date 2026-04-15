import CoreGraphics

struct Capturer: Sendable {
    let manager: any ScreenshotManaging

    func captureWindow(_ window: CapturedWindow) async throws -> CGImage {
        try await manager.capture(.window(id: window.id))
    }

    func captureArea(_ rect: CGRect, displayID: CGDirectDisplayID) async throws -> CGImage {
        try await manager.capture(.area(rect: rect, displayID: displayID))
    }
}
