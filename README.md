# ScreenshotButton

A macOS menu bar app for capturing windows or drawn regions to a PNG file (opened in Preview) or directly to the clipboard.

## Install

```
brew tap greglamb/macos-screenshot-button-app https://github.com/greglamb/macos-screenshot-button-app
brew install --cask screenshotbutton
```

## Use

1. Click the viewfinder icon in the menu bar.
2. Choose **Window to File / Clipboard** or **Area to File / Clipboard**.
3. In window mode, hover a window and click. In area mode, drag a rectangle.
4. Press **Space** to swap mode mid-capture. Press **Esc** to cancel.

File captures open in Preview. Clipboard captures are pasted into any app that accepts images.

## Requirements

- macOS 14 Sonoma or later
- Screen Recording permission (prompted on first capture)

## Develop

```
./bin/setup        # one-time: installs XcodeGen + xcode-build-server, generates project
./bin/regen        # after adding/removing source files
```

Build, test, and run via `xcodebuild` — no Xcode GUI required. See `docs/ARCHITECTURE.md` for the project shape.

## License

MIT — see LICENSE.
