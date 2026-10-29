import Foundation
import Darwin

final class SafetyRunner: CommandRunning, @unchecked Sendable {
    var disabled = true
    var failRestore = false
    var writes = 0
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        if executable == "/usr/bin/pmset", arguments == ["-g"] {
            return CommandResult(status: 0, output: "SleepDisabled \(disabled ? 1 : 0)\n")
        }
        precondition(executable == "/usr/bin/sudo" && arguments == ["-n", "-k", "--", "/usr/bin/pmset", "-a", "disablesleep", "0"], "Watchdog must never enable sleep prevention or invoke other commands")
        writes += 1
        if failRestore { return CommandResult(status: 1, output: "Missing rule") }
        disabled = false
        return CommandResult(status: 0, output: "")
    }
}

final class ArmRunner: CommandRunning, @unchecked Sendable {
    let stateURL: URL
    var disabled = false
    var persistedBeforeEnable = false
    init(_ stateURL: URL) { self.stateURL = stateURL }
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        if executable == "/usr/bin/pmset", arguments == ["-g"] {
            return CommandResult(status: 0, output: "SleepDisabled \(disabled ? 1 : 0)")
        }
        precondition(executable == "/usr/bin/sudo" && arguments == ["-n", "-k", "--", "/usr/bin/pmset", "-a", "disablesleep", "1"])
        let record = try JSONDecoder().decode(SafetyRecord.self, from: Data(contentsOf: stateURL))
        persistedBeforeEnable = record.session != nil && record.session?.deadline != nil
        disabled = true
        return CommandResult(status: 0, output: "")
    }
}

@main
struct SafetyTests {
    static func main() throws {
        var passed = 0
        func check(_ value: Bool, _ label: String) {
            precondition(value, label); passed += 1; print("PASS: \(label)")
        }
        let now = Date()
        func power(_ ac: Bool? = true, _ percent: Int? = 80, _ thermal: ProcessInfo.ThermalState = .nominal, battery: Bool = true) -> PowerSnapshot {
            PowerSnapshot(onAC: ac, batteryPercent: percent, hasBattery: battery, thermalState: thermal)
        }
        let policy = SafetyPolicy()
        check(policy.stopReason(for: power(false, 20)) == .lowBattery, "Stop at battery threshold, including equality")
        check(policy.stopReason(for: power(false, 21)) == nil, "Continue above battery threshold")
        check(policy.stopReason(for: power(true, 5)) == nil, "Low battery does not end an AC session")
        check(SafetyPolicy(onlyOnAC: true).stopReason(for: power(false)) == .acRequired, "AC guard stops when unplugged")
        check(policy.stopReason(for: power(true, nil, battery: false)) == nil, "Desktop Macs without a battery can run on AC")
        check(policy.stopReason(for: power(nil)) == .powerUnknown, "Unreadable power source fails closed")
        check(policy.stopReason(for: power(false, nil)) == .powerUnknown, "Unreadable battery fails closed")
        var lowPower = power(false)
        lowPower.lowPowerMode = true
        check(policy.stopReason(for: lowPower) == nil, "Low Power Mode is opt-in")
        let lowPowerPolicy = SafetyPolicy(stopInLowPowerMode: true)
        check(lowPowerPolicy.stopReason(for: lowPower) == .lowPowerMode, "Low Power Mode guard stops on battery")
        lowPower = power(true)
        lowPower.lowPowerMode = true
        check(lowPowerPolicy.stopReason(for: lowPower) == nil, "Low Power Mode guard permits AC power")
        let previousPolicy = try JSONDecoder().decode(SafetyPolicy.self, from: Data("{\"batteryThreshold\":25,\"onlyOnAC\":true}".utf8))
        check(previousPolicy.batteryThreshold == 25 && previousPolicy.onlyOnAC && !previousPolicy.stopInLowPowerMode,
              "Existing watchdog leases decode without the new optional safeguard")
        for state: ProcessInfo.ThermalState in [.serious, .critical] {
            check(policy.stopReason(for: power(true, 80, state)) == .thermal, "Stop under \(state) thermal pressure")
        }
        let session = SafetySession(heartbeat: now, deadline: now.addingTimeInterval(60), policy: policy)
        check(session.stopReason(at: now, snapshot: power()) == nil, "A healthy live lease continues")
        check(session.stopReason(at: now.addingTimeInterval(60), snapshot: power()) == .deadline, "Independent countdown reaches its deadline")
        check(session.stopReason(at: now.addingTimeInterval(45), snapshot: power()) == .appUnavailable, "Crash or hang expires lease in 45 seconds")
        check(session.stopReason(at: now.addingTimeInterval(-10), snapshot: power()) == .appUnavailable, "Clock rollback expires lease")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LidOffTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runner = SafetyRunner()
        let watchdog = SafetyWatchdog(directory: directory, agentsDirectory: directory, runner: runner,
                                      snapshot: { PowerSnapshot(onAC: true, batteryPercent: 80, hasBattery: true, thermalState: .nominal) })
        func arm(_ task: SafetySession) throws {
            runner.disabled = true
            try watchdog.withLock { try watchdog.writeRecord(SafetyRecord(session: task, lastCheck: now)) }
        }
        try arm(session)
        try watchdog.check(now: now)
        check(runner.disabled && runner.writes == 0, "Watchdog leaves healthy session untouched")
        try watchdog.check(now: now.addingTimeInterval(60))
        check(!runner.disabled && runner.writes == 1, "Watchdog restores sleep with no UI app involved")
        check(try watchdog.readRecord().session == nil && watchdog.readRecord().lastStop == .deadline, "Successful restore clears the lease and preserves reason")
        try arm(session)
        runner.failRestore = true
        do { try watchdog.check(now: now.addingTimeInterval(60)); fatalError("Expected restore failure") }
        catch SleepControlError.oneClickUnavailable { check(try watchdog.readRecord().session != nil, "Failed restore retains lease for retry") }
        runner.failRestore = false
        try watchdog.check(now: now.addingTimeInterval(61))
        check(try !runner.disabled && (watchdog.readRecord()).session == nil, "Next watchdog run retries and restores sleep")
        try arm(session)
        let stop = try watchdog.heartbeat(deadline: nil, policy: policy, now: now.addingTimeInterval(36))
        check(stop == .watchdogUnavailable && !runner.disabled, "UI restores sleep if watchdog stops checking")
        try watchdog.stateURL.writeTestData(Data("broken json".utf8))
        runner.disabled = true
        try watchdog.check(now: now)
        check(try !runner.disabled && (watchdog.readRecord()).session == nil, "Corrupted recovery record restores sleep")
        try watchdog.withLock { try watchdog.writeRecord(SafetyRecord(lastCheck: now)) }
        runner.disabled = true
        let missing = try watchdog.heartbeat(deadline: nil, policy: policy, now: now)
        check(missing == .appUnavailable && !runner.disabled, "Missing lease cannot silently resurrect a session")
        let stateBefore = runner.writes
        do { _ = try watchdog.setDisabled(true, deadline: nil, policy: policy, now: now.addingTimeInterval(30)); fatalError("Expected watchdog failure") }
        catch SafetyStop.watchdogUnavailable { check(runner.writes == stateBefore, "No enabling write when watchdog is stale") }
        let attributes = try FileManager.default.attributesOfItem(atPath: watchdog.stateURL.path)
        check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Session state is private to the user")
        let armDirectory = directory.appendingPathComponent("arm")
        let armRunner = ArmRunner(armDirectory.appendingPathComponent("session.json"))
        let armWatchdog = SafetyWatchdog(directory: armDirectory, agentsDirectory: armDirectory, runner: armRunner,
            snapshot: { PowerSnapshot(onAC: true, batteryPercent: 80, hasBattery: true, thermalState: .nominal) })
        try armWatchdog.withLock { try armWatchdog.writeRecord(SafetyRecord(lastCheck: now)) }
        let enabled = try armWatchdog.setDisabled(true, deadline: now.addingTimeInterval(60), policy: policy, now: now)
        check(enabled && armRunner.persistedBeforeEnable, "Recovery lease is on disk before the enabling command executes")
        let lockFD = open(directory.appendingPathComponent("session.lock").path, O_RDWR)
        precondition(lockFD >= 0 && flock(lockFD, LOCK_EX | LOCK_NB) == 0)
        runner.disabled = true
        let lockStart = ProcessInfo.processInfo.systemUptime
        do { try watchdog.check(now: now); fatalError("Expected locked watchdog failure") }
        catch SafetyStop.watchdogUnavailable {
            check(!runner.disabled && ProcessInfo.processInfo.systemUptime - lockStart < 4, "Frozen lock holder cannot prevent bounded emergency restoration")
        }
        flock(lockFD, LOCK_UN)
        close(lockFD)
        // Real IOKit read only, to catch bridging mistakes without changing power.
        let actual = PowerSnapshot.read()
        check(actual.onAC != nil, "Read live IOKit power source without changing it")
        print("\(passed) safety checks passed; all writes used a fake power controller.")
    }
}

private extension URL {
    func writeTestData(_ data: Data) throws { try data.write(to: self, options: .atomic) }
}
