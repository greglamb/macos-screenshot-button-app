import CoreGraphics
import Foundation
import OSLog
import Observation
import ScreenCaptureKit

@MainActor
@Observable
final class CaptureController {
    let session = CaptureSession()

    private let enumerator: any SCShareableContentProviding
    private let capturer: Capturer
    private let fileSink: FileSink
    private let clipboardSink: ClipboardSink
    private let log = Logger(subsystem: "dev.greglamb.ScreenshotButton", category: "capture")

    init(
        enumerator: any SCShareableContentProviding,
        capturer: Capturer,
        fileSink: FileSink,
        clipboardSink: ClipboardSink
    ) {
        self.enumerator = enumerator
        self.capturer = capturer
        self.fileSink = fileSink
        self.clipboardSink = clipboardSink
    }

    func start(mode: CaptureMode, sink: SinkKind) {
        session.start(mode: mode, sink: sink)
    }

    func cancel() {
        session.cancel()
    }

    func enumerateWindows() async throws -> [CapturedWindow] {
        try await enumerator.shareableContent()
    }

    func commitWindow(_ window: CapturedWindow) async throws {
        session.commit()
        defer { session.finish() }
        let image = try await capturer.captureWindow(window)
        try await deliver(image, sink: session.sink)
    }

    func commitArea(_ rect: CGRect, displayID: CGDirectDisplayID) async throws {
        session.commit()
        defer { session.finish() }
        let image = try await capturer.captureArea(rect, displayID: displayID)
        try await deliver(image, sink: session.sink)
    }

    private func deliver(_ image: CGImage, sink: SinkKind) async throws {
        switch sink {
        case .toFile:
            _ = try await fileSink.deliver(image)
        case .toClipboard:
            clipboardSink.deliver(image)
        }
    }
}

extension CaptureController {
    func enumerateWindowsOrHandle(
        notifier: Notifier,
        onPermissionDenied: @MainActor () -> Void
    ) async -> [CapturedWindow]? {
        do {
            return try await enumerateWindows()
        } catch let error as SCStreamError where error.code == .userDeclined {
            onPermissionDenied()
            return nil
        } catch {
            notifier.post(title: "Capture failed", body: "Please try again.")
            return nil
        }
    }
}
