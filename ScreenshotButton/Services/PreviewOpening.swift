import Foundation

@MainActor
protocol PreviewOpening {
    func open(_ url: URL) async throws
}
