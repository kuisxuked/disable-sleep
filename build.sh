#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/Disable Sleep.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
binaries=()
for architecture in ${ARCHS:-$(uname -m)}; do
    binary="$PWD/.build/DisableSleep-$architecture"
    swiftc -O -swift-version 5 -target "$architecture-apple-macosx13.0" \
        Sources/Localization.swift Sources/SleepControl.swift Sources/OneClickAuthorization.swift \
        Sources/CountdownTask.swift Sources/DurationField.swift Sources/DisableSleep.swift \
        -framework AppKit -framework SwiftUI -o "$binary"
    binaries+=("$binary")
done
lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/DisableSleep"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift Resources/MakeIcon.swift "$PWD/.build" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
