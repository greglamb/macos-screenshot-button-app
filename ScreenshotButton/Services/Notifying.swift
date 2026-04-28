import Foundation

enum PermissionKind: Sendable, Equatable {
    case screenRecording
    case inputMonitoring
}

@MainActor
protocol Notifying {
    func post(title: String, body: String)
    func postPermissionDenied(kind: PermissionKind)
}
