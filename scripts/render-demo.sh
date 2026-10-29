#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx13.0" -D DEMO_EXPORT Sources/*.swift scripts/RenderDemo.swift -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement -framework UserNotifications -framework Carbon -o .build/RenderDemo
printf 'Renderer built: %s\n' "$PWD/.build/RenderDemo"
