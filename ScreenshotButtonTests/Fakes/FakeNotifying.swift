import Foundation

@testable import ScreenshotButton

struct RecordedPost: Equatable {
    let title: String
    let body: String
}

@MainActor
final class FakeNotifying: Notifying {
    var posts: [RecordedPost] = []
    var permissionDeniedKinds: [PermissionKind] = []

    func post(title: String, body: String) {
        posts.append(RecordedPost(title: title, body: body))
    }

    func postPermissionDenied(kind: PermissionKind) {
        permissionDeniedKinds.append(kind)
    }
}
