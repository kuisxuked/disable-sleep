#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
swiftc -swift-version 5 Sources/Localization.swift Sources/SleepControl.swift Sources/OneClickAuthorization.swift Tests/SleepControlTests.swift -o .build/SleepControlTests
.build/SleepControlTests
swiftc -swift-version 5 Sources/Localization.swift Sources/CountdownTask.swift Tests/CountdownTests.swift -o .build/CountdownTests
.build/CountdownTests
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -D DEMO_EXPORT Sources/*.swift Tests/ModelTests.swift -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -framework UserNotifications -framework Carbon -o .build/ModelTests
.build/ModelTests

swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" Sources/Localization.swift Sources/SleepControl.swift Sources/SafetyPolicy.swift Sources/LegacyMigration.swift Sources/SafetyWatchdog.swift Tests/SafetyTests.swift -framework AppKit -framework IOKit -framework ServiceManagement -o .build/SafetyTests
.build/SafetyTests
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -D DEMO_EXPORT Sources/*.swift Tests/ModelFailureTests.swift -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -framework UserNotifications -framework Carbon -o .build/ModelFailureTests
.build/ModelFailureTests
swiftc -swift-version 5 Sources/Automation.swift Tests/AutomationTests.swift -o .build/AutomationTests
.build/AutomationTests
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" Sources/Localization.swift Sources/SleepControl.swift Sources/DisplaySleep.swift Sources/LegacyMigration.swift Tests/DisplaySleepTests.swift -framework AppKit -framework IOKit -o .build/DisplaySleepTests
.build/DisplaySleepTests
