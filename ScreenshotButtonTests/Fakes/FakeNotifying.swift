import Foundation

@testable import ScreenshotButton

struct RecordedPost: Equatable {
    let title: String
    let body: String
}

@MainActor
final class FakeNotifying: Notifying {
    var posts: [RecordedPost] = []
    var permissionDeniedCount = 0

    func post(title: String, body: String) {
        posts.append(RecordedPost(title: title, body: body))
    }

    func postPermissionDenied() {
        permissionDeniedCount += 1
    }
}
