import Foundation
@testable import ScreenshotButton

@MainActor
final class FakeSMAppServiceAPI: SMAppServiceAPI {
    var status: SMAppServiceStatus
    var registerCalls = 0
    var unregisterCalls = 0
    var registerError: Error?
    var unregisterError: Error?

    init(initialStatus: SMAppServiceStatus) {
        self.status = initialStatus
    }

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = .enabled
    }
    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}
