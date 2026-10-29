import Foundation

final class ModelRunner: CommandRunning, @unchecked Sendable {
    var disabled = false
    var failRead = false
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        precondition(executable == "/usr/bin/pmset" && arguments == ["-g"], "Model tests must never run real commands")
        return CommandResult(status: failRead ? 1 : 0, output: failRead ? "Transient read failure" : "SleepDisabled \(disabled ? 1 : 0)")
    }
}

final class ModelWatchdog: SessionProtecting, @unchecked Sendable {
    let power: ModelRunner
    var failWrite = true
    var failInstall = false
    var stop: SafetyStop?
    var deadline: Date?
    init(_ power: ModelRunner) { self.power = power }
    func install() throws { if failInstall { throw SafetyStop.watchdogUnavailable } }
    func setDisabled(_ disabled: Bool, deadline: Date?, policy: SafetyPolicy, now: Date) throws -> Bool {
        if failWrite { throw SleepControlError.oneClickUnavailable("Broken rule") }
        self.deadline = deadline
        power.disabled = disabled
        return disabled
    }
    func heartbeat(deadline: Date?, policy: SafetyPolicy, now: Date) throws -> SafetyStop? { stop }
    func lastStop() throws -> SafetyStop? { stop }
    func uninstall() throws {}
}

struct ModelAuthorization: Authorizing {
    let isInstalled: Bool
    let cancelled: Bool
    func configure(enable: Bool) throws { if cancelled { throw SleepControlError.cancelled } }
}

@main
@MainActor
struct ModelFailureTests {
    static func settle(_ model: SleepModel) async {
        for _ in 0..<500 {
            if !model.busy { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        fatalError("Model operation did not finish")
    }

    static func main() async throws {
        let suite = "LidOffTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        // Reproduce the actual reported failed scheduled ON task with sleep OFF.
        let overdue: [String: Any] = ["deadline": Date().addingTimeInterval(-60).timeIntervalSinceReferenceDate,
                                     "disableSleep": true, "failed": true, "pausedRemaining": 0]
        defaults.set(try JSONSerialization.data(withJSONObject: overdue), forKey: "LidOff.countdown.v1")
        let runner = ModelRunner()
        let watchdog = ModelWatchdog(runner)
        let model = SleepModel(control: SleepControl(runner: runner), authorization: ModelAuthorization(isInstalled: true, cancelled: false), watchdog: watchdog, defaults: defaults)
        model.refresh()
        precondition(model.countdown?.failed == true && model.countdown?.isPaused == false)
        print("PASS: Model refresh keeps a failed task retryable while sleep is OFF")
        model.retryCountdown()
        await settle(model)
        precondition(model.countdown?.failed == true && model.countdown?.isPaused == false && model.message != nil)
        print("PASS: Failed Retry remains visible and available after a broken-rule error")
        watchdog.failWrite = false
        model.retryCountdown()
        await settle(model)
        precondition(model.disabled == true && model.countdown == nil)
        print("PASS: Retry completes and clears the task after authorization is repaired")
        runner.failRead = true
        model.refresh()
        precondition(model.disabled == true && model.message != nil)
        print("PASS: A transient read failure retains the last known power state")
        runner.failRead = false
        watchdog.failInstall = true
        model.toggle(true)
        await settle(model)
        precondition(model.disabled == false && runner.disabled == false)
        print("PASS: An unavailable watchdog restores an inherited ON state")
        let cancelled = SleepModel(control: SleepControl(runner: runner), authorization: ModelAuthorization(isInstalled: false, cancelled: true), watchdog: watchdog, defaults: defaults, authorizationConfirmation: { true })
        watchdog.failInstall = false
        cancelled.refresh()
        cancelled.toggle(true)
        await settle(cancelled)
        precondition(cancelled.disabled == false && cancelled.message == nil && !cancelled.busy)
        print("PASS: First-use administrator cancellation leaves the switch OFF without an error")
        defaults.set(Data("{\"deadline\":1e300,\"disableSleep\":false,\"failed\":false}".utf8), forKey: "LidOff.countdown.v1")
        let corrupt = SleepModel(control: SleepControl(runner: runner), authorization: ModelAuthorization(isInstalled: true, cancelled: false), watchdog: watchdog, defaults: defaults)
        corrupt.refresh()
        precondition(corrupt.countdown == nil && corrupt.disabled == false)
        print("PASS: Corrupt saved preferences do not crash or prevent use of the switch")
        print("7 model failure checks passed with injected controllers; no real power or authorization writes.")
    }
}
