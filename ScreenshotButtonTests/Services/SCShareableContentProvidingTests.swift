import Testing
@testable import ScreenshotButton

@Suite("SCShareableContentProviding")
struct SCShareableContentProvidingTests {
    @Test("Fake returns the injected windows", .timeLimit(.minutes(1)))
    func fakeShareableContentReturnsInjectedWindows() async throws {
        let ws = [CapturedWindow(id: 1, frame: .zero, title: "A", ownerName: "App")]
        let fake = FakeSCShareableContent(result: .success(ws))
        let out = try await fake.shareableContent()
        #expect(out == ws)
    }
}
