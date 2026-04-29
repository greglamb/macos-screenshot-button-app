import Foundation

enum PermissionKind: Sendable, Equatable {
    case screenRecording
    case accessibility
}

@MainActor
protocol Notifying {
    func post(title: String, body: String)
    func postPermissionDenied(kind: PermissionKind)
}
