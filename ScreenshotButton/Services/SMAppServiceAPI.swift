import Foundation

enum SMAppServiceStatus: Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

@MainActor
protocol SMAppServiceAPI: AnyObject {
    var status: SMAppServiceStatus { get }
    func register() throws
    func unregister() throws
}
