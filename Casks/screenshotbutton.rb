cask "screenshotbutton" do
  version "0.0.5"
  sha256 "3aa8d68602044763d56a1e632b40578b3d27c9d15fffaf12cc752a20544adcdc"

  url "https://github.com/greglamb/macos-screenshot-button-app/releases/download/v#{version}/ScreenshotButton-#{version}.dmg"
  name "ScreenshotButton"
  desc "Menu bar app for window and area screenshots to file or clipboard"
  homepage "https://github.com/greglamb/macos-screenshot-button-app"

  depends_on macos: ">= :sonoma"

  app "ScreenshotButton.app"

  zap trash: [
    "~/Library/Preferences/dev.greglamb.ScreenshotButton.plist",
  ]
end
