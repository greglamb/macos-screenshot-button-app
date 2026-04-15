cask "screenshotbutton" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/greglamb/macos-screenshot-button/releases/download/v#{version}/ScreenshotButton-#{version}.dmg"
  name "ScreenshotButton"
  desc "Menu bar app for window and area screenshots to file or clipboard"
  homepage "https://github.com/greglamb/macos-screenshot-button"

  depends_on macos: ">= :sonoma"

  app "ScreenshotButton.app"

  zap trash: [
    "~/Library/Preferences/dev.greglamb.ScreenshotButton.plist",
  ]
end
