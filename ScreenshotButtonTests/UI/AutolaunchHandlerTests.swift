import Foundation
import Testing

@testable import ScreenshotButton

private struct LaunchError: Error, Equatable {}

@MainActor
@Suite("AutolaunchToggleHandler")
struct AutolaunchHandlerTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AutolaunchHandlerTests-\(UUID())")!
    }

    @Test("Success returns the new value and posts nothing")
    func successReturnsNewValue() {
        let defaults = makeDefaults()
        let api = FakeSMAppServiceAPI(initialStatus: .notRegistered)
        let la = LaunchAtLogin(api: api, defaults: defaults)
        let notifier = FakeNotifying()
        let handler = AutolaunchToggleHandler(launchAtLogin: la, notifier: notifier)

        let result = handler.setEnabled(true)

        #expect(result == true)
        #expect(notifier.posts.isEmpty)
    }

    @Test("Failure reverts to current state and posts an explanatory notification")
    func failureRevertsAndNotifies() {
        let defaults = makeDefaults()
        let api = FakeSMAppServiceAPI(initialStatus: .notRegistered)
        api.registerError = LaunchError()
        let la = LaunchAtLogin(api: api, defaults: defaults)
        let notifier = FakeNotifying()
        let handler = AutolaunchToggleHandler(launchAtLogin: la, notifier: notifier)

        let result = handler.setEnabled(true)

        #expect(result == false)  // reverted to current persisted state
        #expect(
            notifier.posts == [
                RecordedPost(
                    title: "Couldn't update Launch at Login",
                    body:
                        "Try again in a moment. If the problem persists, open System Settings → General → Login Items."
                )
            ])
    }

    @Test("Disabling on success returns false and posts nothing")
    func disableSuccessReturnsFalse() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: LaunchAtLogin.defaultsKey)  // seed: currently enabled
        let api = FakeSMAppServiceAPI(initialStatus: .enabled)
        let la = LaunchAtLogin(api: api, defaults: defaults)
        let notifier = FakeNotifying()
        let handler = AutolaunchToggleHandler(launchAtLogin: la, notifier: notifier)

        let result = handler.setEnabled(false)

        #expect(result == false)
        #expect(api.unregisterCalls == 1)
        #expect(notifier.posts.isEmpty)
    }
}
