import Testing
import Foundation
@testable import ScreenshotButton

@MainActor
@Suite("Notifier")
struct NotifierTests {
    @Test("Open Settings action routes to the Screen Recording privacy URL")
    func openSettingsActionRoutesToScreenRecordingURL() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: Notifier.openSettingsAction)

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        #expect(opener.openedURLs == [expected])
    }

    @Test("Unknown action identifier is a no-op")
    func unknownActionIsNoOp() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: "SOME_OTHER_ACTION")

        #expect(opener.openedURLs.isEmpty)
    }
}
