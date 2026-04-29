import Foundation
import Testing

@testable import ScreenshotButton

@MainActor
@Suite("Notifier")
struct NotifierTests {
    @Test("Open Settings action routes to the Screen Recording privacy URL")
    func screenRecordingActionRoutes() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: Notifier.openScreenRecordingSettingsAction)

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        #expect(opener.openedURLs == [expected])
    }

    @Test("Open Settings action routes to the Accessibility privacy URL")
    func accessibilityActionRoutes() async {
        let opener = FakeURLOpener()
        let notifier = Notifier(opener: opener)

        await notifier.handle(actionIdentifier: Notifier.openAccessibilitySettingsAction)

        let expected = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
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
