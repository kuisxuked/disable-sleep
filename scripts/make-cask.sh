#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 1; }
archive="dist/LidOff-$version-macOS-universal.zip"
checksum=$(shasum -a 256 "$archive")
checksum=${checksum%% *}
cat <<RUBY
cask "lidoff" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/kuisxuked/lidoff/releases/download/v#{version}/LidOff-#{version}-macOS-universal.zip"
  name "LidOff"
  desc "Menu bar sleep controls with a safety watchdog"
  homepage "https://github.com/kuisxuked/lidoff"

  depends_on macos: ">= :ventura"

  app "LidOff.app"
  binary "#{appdir}/LidOff.app/Contents/MacOS/LidOff", target: "lidoff"

  caveats <<~EOS
    Before uninstalling, use Options & safety -> Remove authorization and quit.
    Deleting the app alone leaves its sudoers rule and safety watchdog installed.
    Community builds are ad-hoc signed and may require Open Anyway in macOS.
  EOS
end
RUBY
