#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ARCHS='arm64 x86_64' ./build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
mkdir -p dist
archive="DisableSleep-$version-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent 'Disable Sleep.app' "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS.txt)
codesign --verify --strict 'Disable Sleep.app'
lipo -info 'Disable Sleep.app/Contents/MacOS/DisableSleep'
printf 'Release ready: dist/%s\n' "$archive"
