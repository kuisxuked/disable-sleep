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
swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -D DEMO_EXPORT Sources/*.swift Tests/ModelTests.swift -framework AppKit -framework SwiftUI -o .build/ModelTests
.build/ModelTests
