import SwiftUI

@main
struct ScreenshotButtonApp: App {
    @State private var controller: CaptureController = .live()
    private let launchAtLogin = LaunchAtLogin()

    var body: some Scene {
        MenuBarExtra {
            MenuView(launchAtLogin: launchAtLogin) { mode, sink in
                controller.start(mode: mode, sink: sink)
            }
        } label: {
            Image(systemName: "viewfinder")
                .accessibilityLabel("ScreenshotButton")
        }
    }
}

extension CaptureController {
    @MainActor
    static func live() -> CaptureController {
        CaptureController(
            enumerator: WindowEnumerator(),
            capturer: Capturer(manager: SCScreenshotManagerAdapter()),
            fileSink: FileSink(),
            clipboardSink: ClipboardSink()
        )
    }
}
