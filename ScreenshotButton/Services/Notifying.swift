import Foundation

@MainActor
protocol Notifying {
    func post(title: String, body: String)
    func postPermissionDenied()
}
