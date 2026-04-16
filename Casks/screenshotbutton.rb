cask "screenshotbutton" do
  version "0.0.6"
  sha256 "88c0d2c650c4f26de53435209fca332eb0b99db7aa21b71f547ff58cafae27b8"

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
