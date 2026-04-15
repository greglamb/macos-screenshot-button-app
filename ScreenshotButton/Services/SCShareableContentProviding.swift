import Foundation

protocol SCShareableContentProviding: Sendable {
    func shareableContent() async throws -> [CapturedWindow]
}
