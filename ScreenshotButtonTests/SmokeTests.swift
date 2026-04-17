import Testing

@testable import ScreenshotButton

@Suite("Smoke")
struct SmokeTests {
    @Test("Project builds and tests run")
    func projectBuildsAndTestsRun() {
        #expect(true)
    }
}
