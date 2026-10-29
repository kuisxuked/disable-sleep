import Foundation
import IOKit.pwr_mgt

final class FakeDisplayAssertions: DisplayAssertions {
    var displayCreates = 0
    var activityInputs: [IOPMAssertionID] = []
    var released: [IOPMAssertionID] = []
    var failActivity = false
    func createDisplay() throws -> IOPMAssertionID { displayCreates += 1; return 10 }
    func declareActivity(reusing id: IOPMAssertionID) throws -> IOPMAssertionID {
        activityInputs.append(id)
        if failActivity { throw SleepControlError.commandFailed("Injected activity failure") }
        return 20
    }
    func release(_ id: IOPMAssertionID) { released.append(id) }
}

@main
@MainActor
struct DisplaySleepTests {
    static func main() throws {
        let api = FakeDisplayAssertions()
        var display: DisplaySleep? = DisplaySleep(api: api)
        try display!.update(keepAwake: false, uptime: 0)
        precondition(api.displayCreates == 0 && api.activityInputs.isEmpty)
        try display!.update(keepAwake: true, uptime: 1)
        precondition(api.displayCreates == 1 && api.activityInputs.isEmpty)
        try display!.update(keepAwake: true, preventIdleLock: true, uptime: 2)
        try display!.update(keepAwake: true, preventIdleLock: true, uptime: 16)
        precondition(api.activityInputs == [0])
        try display!.update(keepAwake: true, preventIdleLock: true, uptime: 17)
        precondition(api.displayCreates == 1 && api.activityInputs == [0, 20])
        print("PASS: Display-only mode reports no activity; idle prevention renews after 15 seconds using the returned ID")
        try display!.update(keepAwake: true, preventIdleLock: false, uptime: 18)
        precondition(api.released == [20])
        try display!.update(keepAwake: false, uptime: 19)
        precondition(api.released == [20, 10])
        try display!.update(keepAwake: false, preventIdleLock: true, uptime: 20)
        precondition(api.displayCreates == 2 && api.activityInputs.last == 0)
        display = nil
        precondition(api.released == [20, 10, 20, 10])
        print("PASS: Disabling idle prevention releases activity separately; session end and deinit release all assertions")

        let failing = DisplaySleep(api: api)
        api.failActivity = true
        do {
            try failing.update(keepAwake: true, preventIdleLock: true, uptime: 30)
            fatalError("Expected failure")
        } catch SleepControlError.commandFailed {}
        api.failActivity = false
        try failing.update(keepAwake: true, preventIdleLock: true, uptime: 31)
        precondition(api.activityInputs.suffix(2) == [0, 0])
        try failing.update(keepAwake: false, uptime: 32)
        print("PASS: Failed activity declarations remain retryable and cleanup remains available")

        let name = "LidOffMigrationTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(30, forKey: "LidOff.batteryThreshold")
        LegacyMigration.importPreferences(defaults: defaults, legacy: ["DisableSleep.language": "zh", "DisableSleep.batteryThreshold": 20])
        precondition(defaults.string(forKey: "LidOff.language") == "zh" && defaults.integer(forKey: "LidOff.batteryThreshold") == 30)
        LegacyMigration.importPreferences(defaults: defaults, legacy: ["DisableSleep.language": "en"])
        precondition(defaults.string(forKey: "LidOff.language") == "zh")
        print("PASS: Rename imports old preferences once and preserves existing LidOff choices")
        print("All display and preference migration checks passed with fake assertions; no lock settings or real power state changed.")
    }
}
