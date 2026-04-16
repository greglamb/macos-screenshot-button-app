import Foundation
import ScreenCaptureKit

struct WindowEnumerator: SCShareableContentProviding {
    func shareableContent() async throws -> [CapturedWindow] {
        let content = try await SCShareableContent.current
        return content.windows
            // Only normal-level windows. Excludes desktop wallpaper (negative
            // layer), dock and menu bar (high layers), notification center,
            // floating panels, and other system chrome that we don't want
            // the picker to highlight.
            .filter { $0.windowLayer == 0 }
            .filter { $0.isOnScreen }
            .filter { $0.owningApplication != nil }
            .filter { ($0.title ?? "").isEmpty == false }
            // Drop sub-pixel windows (tooltips, invisible helpers).
            .filter { $0.frame.width >= 1 && $0.frame.height >= 1 }
            // SCK's window order isn't documented as front-to-back, so we sort
            // by frame area ascending — when overlapping windows share a point,
            // the smaller (typically inner/frontmost-by-intent) wins the hit
            // test in `HitTesting.topmost`. This matches macOS's built-in
            // `Cmd-Shift-4-Space` behavior of preferring the most specific window.
            .sorted { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
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
