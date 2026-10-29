#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/LidOff.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
binaries=()
for architecture in ${ARCHS:-$(uname -m)}; do
    binary="$PWD/.build/LidOff-$architecture"
    swiftc -O -swift-version 5 -target "$architecture-apple-macosx13.0" \
        Sources/Localization.swift Sources/SleepControl.swift Sources/OneClickAuthorization.swift \
        Sources/CountdownTask.swift Sources/SafetyPolicy.swift Sources/LegacyMigration.swift Sources/SafetyWatchdog.swift \
        Sources/DisplaySleep.swift Sources/GlobalHotKey.swift Sources/SessionNotifications.swift Sources/Automation.swift Sources/DurationField.swift Sources/LidOff.swift \
        -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -framework UserNotifications -framework Carbon -o "$binary"
    binaries+=("$binary")
    swiftc -O -swift-version 5 -target "$architecture-apple-macosx13.0" \
        Sources/Localization.swift Sources/SleepControl.swift Sources/SafetyPolicy.swift Sources/LegacyMigration.swift Sources/SafetyWatchdog.swift Watchdog/main.swift \
        -framework AppKit -framework IOKit -framework ServiceManagement -o "$PWD/.build/Watchdog-$architecture"
done
lipo -create "${binaries[@]}" -output "$APP/Contents/MacOS/LidOff"
helpers=()
for architecture in ${ARCHS:-$(uname -m)}; do helpers+=("$PWD/.build/Watchdog-$architecture"); done
lipo -create "${helpers[@]}" -output "$APP/Contents/MacOS/LidOffWatchdog"
signing_identity="${CODESIGN_IDENTITY:--}"
signing_options=(--force --sign "$signing_identity" --options runtime)
if [[ "$signing_identity" != "-" ]]; then signing_options+=(--timestamp); fi
codesign "${signing_options[@]}" "$APP/Contents/MacOS/LidOffWatchdog"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift Resources/MakeIcon.swift "$PWD/.build" "$APP/Contents/Resources/AppIcon.icns"
codesign "${signing_options[@]}" "$APP"
printf 'Built %s\n' "$APP"
