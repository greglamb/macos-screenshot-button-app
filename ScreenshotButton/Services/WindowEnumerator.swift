import Foundation
import ScreenCaptureKit

struct WindowEnumerator: SCShareableContentProviding {
    func shareableContent() async throws -> [CapturedWindow] {
        let content = try await SCShareableContent.current
        // SCShareableContent.windows is documented as being in front-to-back order.
        return content.windows
            .filter { $0.isOnScreen }
            .filter { $0.owningApplication != nil }
            .filter { ($0.title ?? "").isEmpty == false }
            .map { sc in
                CapturedWindow(
                    id: sc.windowID,
                    frame: sc.frame,
                    title: sc.title,
                    ownerName: sc.owningApplication?.applicationName
                )
            }
    }
}
