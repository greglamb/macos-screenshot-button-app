import Foundation
import Observation

@MainActor
@Observable
final class CaptureSession {
    enum State: Equatable, Sendable {
        case idle
        case capturing
        case delivering
    }

    private(set) var state: State = .idle
    private(set) var mode: CaptureMode = .window
    private(set) var sink: SinkKind = .toFile
    private(set) var hoveredWindow: CapturedWindow?

    init() {}

    func start(mode: CaptureMode, sink: SinkKind) {
        guard state == .idle else { return }
        self.mode = mode
        self.sink = sink
        self.hoveredWindow = nil
        self.state = .capturing
    }

    func toggle() {
        guard state == .capturing else { return }
        mode = (mode == .window) ? .area : .window
        hoveredWindow = nil
    }

    func hover(_ window: CapturedWindow?) {
        guard state == .capturing, mode == .window else {
            hoveredWindow = nil
            return
        }
        hoveredWindow = window
    }

    func cancel() {
        guard state == .capturing else { return }
        state = .idle
        hoveredWindow = nil
    }

    func commit() {
        guard state == .capturing else { return }
        state = .delivering
    }

    func finish() {
        state = .idle
        hoveredWindow = nil
    }
}
