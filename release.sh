#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ -n "${NOTARYTOOL_PROFILE:-}" && "${CODESIGN_IDENTITY:--}" == "-" ]]; then
    echo 'Notarization requires CODESIGN_IDENTITY set to a Developer ID Application identity.' >&2
    exit 1
fi
./test.sh
ARCHS='arm64 x86_64' ./build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
mkdir -p dist
archive="LidOff-$version-macOS-universal.zip"
codesign --verify --deep --strict 'LidOff.app'
lipo -info 'LidOff.app/Contents/MacOS/LidOff'
lipo -info 'LidOff.app/Contents/MacOS/LidOffWatchdog'
ditto -c -k --sequesterRsrc --keepParent 'LidOff.app' "dist/$archive"
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "dist/$archive" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    xcrun stapler staple 'LidOff.app'
    xcrun stapler validate 'LidOff.app'
    ditto -c -k --sequesterRsrc --keepParent 'LidOff.app' "dist/$archive"
fi
cp "dist/$archive" dist/LidOff-macOS-universal.zip
./scripts/make-cask.sh > dist/lidoff.rb
(cd dist && shasum -a 256 "$archive" LidOff-macOS-universal.zip lidoff.rb > SHA256SUMS.txt)
printf 'Release ready: dist/%s\n' "$archive"
