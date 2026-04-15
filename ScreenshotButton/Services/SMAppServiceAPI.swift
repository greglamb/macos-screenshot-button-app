import Foundation
import ServiceManagement

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

@MainActor
final class SystemSMAppService: SMAppServiceAPI {
    var status: SMAppServiceStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}
