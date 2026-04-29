cask "screenshotbutton" do
  version "0.0.7"
  sha256 "d558b9e62d4117c5dc383c086107d1bf332b423277fedf2a00ffc772a3e17e4d"

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
