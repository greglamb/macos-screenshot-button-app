import CoreGraphics
import Foundation
import ScreenCaptureKit

struct WindowEnumerator: SCShareableContentProviding {
    func shareableContent() async throws -> [CapturedWindow] {
        let content = try await SCShareableContent.current

        // Apply our filters, keyed by window ID for a z-order join below.
        let scByID: [CGWindowID: SCWindow] = Dictionary(
            uniqueKeysWithValues: content.windows
                .filter { $0.windowLayer == 0 }  // normal-level only
                .filter { $0.isOnScreen }
                .filter { $0.owningApplication != nil }
                .filter { ($0.title ?? "").isEmpty == false }
                .filter { $0.frame.width >= 1 && $0.frame.height >= 1 }
                .map { ($0.windowID, $0) }
        )

        // CGWindowListCopyWindowInfo is documented to return on-screen
        // windows in front-to-back order (`kCGWindowListOptionOnScreenOnly`).
        // SCK's `content.windows` has no documented ordering, so we use
        // CGWindowList as the z-order source of truth and intersect by ID.
        // Both APIs require Screen Recording TCC; we already have that.
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let orderedIDs: [CGWindowID] = info.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }

        return orderedIDs.compactMap { id -> CapturedWindow? in
            guard let sc = scByID[id] else { return nil }
            return CapturedWindow(
                id: sc.windowID,
                frame: sc.frame,
                title: sc.title,
                ownerName: sc.owningApplication?.applicationName
            )
        }
    }
}
