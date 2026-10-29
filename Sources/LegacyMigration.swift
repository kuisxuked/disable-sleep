import Foundation
import AppKit
import Darwin

/// Old names appear only here and in the authorization migration so existing
/// installations can upgrade without leaving a competing recovery agent behind.
enum LegacyMigration {
    static let bundleID = "local.disablesleep.app"
    static let watchdogLabel = "local.disablesleep.watchdog"

    static func importPreferences(defaults: UserDefaults = .standard,
                                  legacy: [String: Any]? = nil) {
        guard !defaults.bool(forKey: "LidOff.importedPreferences.v1") else { return }
        let previous = legacy ?? defaults.persistentDomain(forName: bundleID) ?? [:]
        for (key, value) in previous where key.hasPrefix("DisableSleep.") {
            let destination = "LidOff." + key.dropFirst("DisableSleep.".count)
            if defaults.object(forKey: destination) == nil { defaults.set(value, forKey: destination) }
        }
        defaults.set(true, forKey: "LidOff.importedPreferences.v1")
    }

    static func retireWatchdog(runner: any CommandRunning,
                               home: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else {
            throw SleepControlError.commandFailed(AppLanguage.current.text(
                "请先退出旧版应用，再在 LidOff 中开启会话。", "Quit the previous app before starting a LidOff session."))
        }
        let fm = FileManager.default
        let plist = home.appendingPathComponent("Library/LaunchAgents/" + watchdogLabel + ".plist")
        let directory = home.appendingPathComponent("Library/Application Support/Disable Sleep")
        let service = "gui/\(getuid())/\(watchdogLabel)"
        let registered = try runner.run("/bin/launchctl", arguments: ["print", service]).status == 0
        guard registered || fm.fileExists(atPath: plist.path) || fm.fileExists(atPath: directory.path) else { return }
        // Restore before removing the recovery agent. Failed restoration aborts
        // migration and leaves its recovery state available for the next retry.
        _ = try SleepControl(runner: runner).setDisabled(false)
        let result = try runner.run("/bin/launchctl", arguments: ["bootout", service])
        if result.status != 0, try runner.run("/bin/launchctl", arguments: ["print", service]).status == 0 {
            throw SleepControlError.commandFailed(result.output)
        }
        if fm.fileExists(atPath: plist.path) { try fm.removeItem(at: plist) }
        if fm.fileExists(atPath: directory.path) { try fm.removeItem(at: directory) }
    }
}
