// swift-tools-version: 5.9
import PackageDescription

// Open this package in Xcode for source navigation and app debugging. The build
// script assembles the .app with Info.plist, icons, and the separate watchdog.
let package = Package(
    name: "LidOff",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LidOff", targets: ["LidOff"])],
    targets: [.executableTarget(name: "LidOff", path: "Sources", linkerSettings: [
        .linkedFramework("AppKit"), .linkedFramework("SwiftUI"),
        .linkedFramework("IOKit"), .linkedFramework("ServiceManagement"), .linkedFramework("UserNotifications"), .linkedFramework("Carbon")
    ])],
    swiftLanguageVersions: [.v5]
)
