import CoreGraphics

struct CapturedWindow: Equatable, Sendable, Identifiable {
    let id: CGWindowID
    /// Global screen coordinates in **Cocoa space** (bottom-left origin),
    /// matching `NSEvent.mouseLocation` and `NSScreen.frame`. SCK returns
    /// frames in Quartz space — `OverlayManager` flips Y at the boundary
    /// so the rest of the app can ignore the difference.
    let frame: CGRect
    let title: String?
    let ownerName: String?
}
