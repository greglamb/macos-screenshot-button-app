import Testing
import CoreGraphics
@testable import ScreenshotButton

@MainActor
@Suite("Capturer")
struct CapturerTests {
    @Test("Forwards a window target to the manager", .timeLimit(.minutes(1)))
    func capturerForwardsWindowTarget() async throws {
        let fake = FakeScreenshotManager()
        let capturer = Capturer(manager: fake)
        let win = CapturedWindow(id: 7, frame: .init(x: 0, y: 0, width: 100, height: 100), title: nil, ownerName: nil)

        _ = try await capturer.captureWindow(win)
        let target = await fake.lastTarget
        #expect(target == .window(id: 7))
    }

    @Test("Forwards an area target to the manager", .timeLimit(.minutes(1)))
    func capturerForwardsAreaTarget() async throws {
        let fake = FakeScreenshotManager()
        let capturer = Capturer(manager: fake)
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

        _ = try await capturer.captureArea(rect, displayID: 99)
        let target = await fake.lastTarget
        #expect(target == .area(rect: rect, displayID: 99))
    }
}
