import CoreGraphics
import ScreenCaptureKit

struct SCScreenshotManagerAdapter: ScreenshotManaging {
    func capture(_ target: CaptureTarget) async throws -> CGImage {
        switch target {
        case .window(let id):
            let content = try await SCShareableContent.current
            guard let scWindow = content.windows.first(where: { $0.windowID == id }) else {
                throw CaptureError.windowGone
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(scWindow.frame.width * 2)   // Retina
            config.height = Int(scWindow.frame.height * 2)
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        case .area(let rect, let displayID):
            let content = try await SCShareableContent.current
            guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.displayGone
            }
            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = rect
            config.width = Int(rect.width * 2)
            config.height = Int(rect.height * 2)
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        }
    }
}

enum CaptureError: Error, Equatable {
    case windowGone
    case displayGone
}
