import CoreGraphics

struct CapturedWindow: Equatable, Sendable, Identifiable {
    let id: CGWindowID
    let frame: CGRect        // global screen coordinates
    let title: String?
    let ownerName: String?
}
