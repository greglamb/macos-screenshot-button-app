cask "screenshotbutton" do
  version "0.0.5"
  sha256 "e7783b0168f5c9e1775f3f8e722e5c9ee323bb5c4035e7654f8a710ff79e4cef"

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
