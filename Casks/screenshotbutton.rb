cask "screenshotbutton" do
  version "0.0.8"
  sha256 "db61ae21a87bf046e819636c85afbf75cecacc3b7cea401474df9cdbb7644fd7"

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
