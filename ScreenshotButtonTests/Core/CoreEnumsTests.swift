import Testing
@testable import ScreenshotButton

@Suite("Core enums")
struct CoreEnumsTests {
    @Test("CaptureMode is Sendable and Equatable")
    func captureModeIsSendableAndEquatable() {
        let a: CaptureMode = .window
        let b: CaptureMode = .area
        #expect(a != b)
        #expect(a == .window)
    }

    @Test("SinkKind is Sendable and Equatable")
    func sinkKindIsSendableAndEquatable() {
        let a: SinkKind = .toFile
        let b: SinkKind = .toClipboard
        #expect(a != b)
        #expect(a == .toFile)
    }
}
