# Architecture

## Overview

**macos-screenshot-button** is a macOS utility (Swift/SwiftUI) for capturing windows or drawn regions to a PNG file (opened in Preview) or the system clipboard.

- Platform: macOS 14+ (Sonoma)
- Language: Swift 6 (strict concurrency)
- UI: SwiftUI (`MenuBarExtra` + `@Observable`) with thin AppKit overlay (`NSPanel`) for capture-time event capture
- Persistence: none
- Distribution: Homebrew cask hosted in this repo, signed and notarized via GitHub Actions

## Project file generation

The Xcode project (`ScreenshotButton.xcodeproj`) is generated from `Project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Source of truth is `Project.yml`; the generated `.xcodeproj` is committed for low-friction `xcodebuild` use but always regenerable.

To set up a fresh checkout:
```
./bin/setup
```

This installs XcodeGen and `xcode-build-server` via Homebrew if missing, regenerates the `.xcodeproj`, and writes `buildServer.json` so SourceKit understands the project structure.

## Module layout (target: when scaffolding completes)

```
ScreenshotButton/
├── Core/              value types: CaptureMode, SinkKind, CapturedWindow, AreaGeometry, HitTesting
├── Services/          protocol-wrapped Apple APIs: WindowEnumerator, Capturer, FileSink,
│                      ClipboardSink, LaunchAtLogin, TempCleanup, Notifier, PNGEncoder
├── Session/           CaptureSession (state machine), CaptureController (coordinator)
├── UI/                ScreenshotButtonApp, MenuView, OverlayPanel, OverlayView, OverlayManager
├── Info.plist         generated from Project.yml
└── ScreenshotButtonApp.swift   @main entry point

ScreenshotButtonTests/
├── Core/              pure-logic tests (Swift Testing)
├── Services/          service tests with injected fakes
├── Session/           state-machine and coordinator tests
├── Fakes/             FakeSCShareableContent, FakeScreenshotManager (actor),
│                      FakeFileWriter, FakePreviewOpener, FakePasteboard, FakeSMAppServiceAPI
└── Support/           Tags.swift (Swift Testing custom tags: .slow, .fileSystem, .ui)
```

(Sub-directories are created as the corresponding tasks land.)

## Dependencies

None. The app uses only system frameworks: SwiftUI, AppKit, ScreenCaptureKit, ServiceManagement, UserNotifications, Foundation, CoreGraphics, ImageIO.

## Data flow

```
Menu click  →  OverlayManager.begin(mode:sink:)
            →  CaptureController.start(mode:sink:)  (CaptureSession → .capturing)
            →  Per-screen NSPanel overlays presented
            →  User clicks window OR drags rectangle
            →  OverlayManager.didClickWindow / didCompleteArea
            →  CaptureController.commitWindow / commitArea
                 (CaptureSession → .delivering)
            →  Capturer.capture(target)  →  CGImage
            →  Sink:
                 .toFile        → PNGEncoder → FileWriter → PreviewOpener (NSWorkspace)
                 .toClipboard   → NSImage → PasteboardWriting
            →  CaptureSession.finish() → .idle
```

## Design and plan documents

- Spec: `docs/superpowers/specs/2026-04-14-screenshotbutton-design.md`
- Plan: `docs/superpowers/plans/2026-04-14-initial-implementation.md`
