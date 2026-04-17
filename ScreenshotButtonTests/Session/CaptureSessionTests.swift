import Testing

@testable import ScreenshotButton

@MainActor
@Suite("CaptureSession state machine")
struct CaptureSessionTests {
    let s = CaptureSession()

    @Test("Starts in idle with no hover")
    func startsInIdle() {
        #expect(s.state == .idle)
        #expect(s.hoveredWindow == nil)
    }

    @Test("start() transitions to capturing with chosen mode and sink")
    func startTransitionsToCapturingWithModeAndSink() {
        s.start(mode: .window, sink: .toFile)
        #expect(s.state == .capturing)
        #expect(s.mode == .window)
        #expect(s.sink == .toFile)
    }

    @Test("start() is a no-op when already capturing")
    func startIsNoOpWhenNotIdle() {
        s.start(mode: .window, sink: .toFile)
        s.start(mode: .area, sink: .toClipboard)
        #expect(s.mode == .window)
        #expect(s.sink == .toFile)
    }

    @Test("toggle() swaps mode and clears hover")
    func toggleSwapsModeAndClearsHover() {
        s.start(mode: .window, sink: .toFile)
        s.hover(CapturedWindow(id: 1, frame: .zero, title: nil, ownerName: nil))
        s.toggle()
        #expect(s.mode == .area)
        #expect(s.hoveredWindow == nil)
        s.toggle()
        #expect(s.mode == .window)
    }

    @Test("toggle() is ignored while idle")
    func toggleIgnoredWhenIdle() {
        s.toggle()
        #expect(s.mode == .window)  // default
        #expect(s.state == .idle)
    }

    @Test("hover only updates in window mode")
    func hoverOnlyUpdatesInWindowMode() {
        let win = CapturedWindow(id: 1, frame: .zero, title: nil, ownerName: nil)
        s.start(mode: .window, sink: .toFile)
        s.hover(win)
        #expect(s.hoveredWindow == win)
        s.toggle()  // -> area
        s.hover(win)
        #expect(s.hoveredWindow == nil)
    }

    @Test("cancel() returns to idle")
    func cancelReturnsToIdle() {
        s.start(mode: .window, sink: .toFile)
        s.cancel()
        #expect(s.state == .idle)
        #expect(s.hoveredWindow == nil)
    }

    @Test("commit() moves to delivering and finish() returns to idle")
    func commitMovesToDeliveringThenFinishReturnsToIdle() {
        s.start(mode: .window, sink: .toFile)
        s.commit()
        #expect(s.state == .delivering)
        s.finish()
        #expect(s.state == .idle)
    }

    @Test("cancel() has no effect while delivering")
    func cancelHasNoEffectDuringDelivering() {
        s.start(mode: .window, sink: .toFile)
        s.commit()
        s.cancel()
        #expect(s.state == .delivering)
    }
}
