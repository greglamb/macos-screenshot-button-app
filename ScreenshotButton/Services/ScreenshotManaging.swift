import CoreGraphics

enum CaptureTarget: Equatable, Sendable {
    case window(id: CGWindowID)
    case area(rect: CGRect, displayID: CGDirectDisplayID)
}

protocol ScreenshotManaging: Sendable {
    func capture(_ target: CaptureTarget) async throws -> CGImage
}
