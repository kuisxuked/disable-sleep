import Foundation

// Tests invoke this runner sequentially on the main thread.
final class FakeRunner: CommandRunning, @unchecked Sendable {
    var results: [CommandResult]
    var calls: [(String, [String])] = []
    init(_ results: [CommandResult]) { self.results = results }
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        calls.append((executable, arguments))
        precondition(!results.isEmpty, "Unexpected command: \(executable)")
        return results.removeFirst()
    }
}

@main
struct SleepControlTests {
    static func state(_ disabled: Bool) -> CommandResult {
        CommandResult(status: 0, output: "System-wide power settings:\n SleepDisabled\t\t\(disabled ? 1 : 0)\n")
    }

    static func main() throws {
        var passed = 0
        func check(_ condition: Bool, _ label: String) {
            guard condition else { fatalError("FAIL: \(label)") }
            passed += 1
            print("PASS: \(label)")
        }

        let enabled = try SleepControl.parseState("System-wide power settings:\n SleepDisabled\t\t1\n")
        check(enabled, "Read enabled state with tabs")
        let disabled = try SleepControl.parseState(" SleepDisabled       0\r\n")
        check(!disabled, "Read disabled state with spaces")
        let freshMac = try SleepControl.parseState("Currently in use:\n sleep 1\n displaysleep 10\n")
        check(!freshMac, "Fresh Macs without an explicit SleepDisabled key allow sleep")
        for output in ["", "SleepDisabled 2", "SleepDisabled 1 extra", "sleep 1", "NotSleepDisabled 1"] {
            do {
                _ = try SleepControl.parseState(output)
                fatalError("Invalid output accepted")
            } catch SleepControlError.unreadableState {
                check(true, "Reject ambiguous state: \(output.debugDescription)")
            }
        }

        for target in [true, false] {
            let runner = FakeRunner([state(!target), CommandResult(status: 0, output: ""), state(target)])
            let actual = try SleepControl(runner: runner).setDisabled(target)
            check(actual == target, "Verify \(target ? "ON" : "OFF") after authorization")
            check(runner.calls[1].0 == "/usr/bin/sudo" && runner.calls[1].1 == ["-n", "-k", "--", "/usr/bin/pmset", "-a", "disablesleep", target ? "1" : "0"], "Run exact \(target ? 1 : 0) command without password or cached credentials")
            check(runner.calls.first?.0 == "/usr/bin/pmset" && runner.calls.last?.0 == "/usr/bin/pmset", "Read actual setting before and after write")
        }

        let unchanged = FakeRunner([state(true)])
        _ = try SleepControl(runner: unchanged).setDisabled(true)
        check(unchanged.calls.count == 1, "Skip authorization if requested state already applies")

        let cancelled = FakeRunner([CommandResult(status: 0, output: "LIDOFF_USER_CANCELLED\n")])
        do {
            try OneClickAuthorization(runner: cancelled).configure(enable: true)
            fatalError("Cancellation not detected")
        } catch SleepControlError.cancelled {
            check(cancelled.calls.count == 1, "Handle one-time setup cancellation")
        }

        let denied = FakeRunner([state(false), CommandResult(status: 1, output: "Authorization denied")])
        do {
            _ = try SleepControl(runner: denied).setDisabled(true)
            fatalError("Failure not detected")
        } catch SleepControlError.oneClickUnavailable(let detail) {
            check(detail == "Authorization denied", "Missing permission reports setup guidance without prompting")
        }

        let mismatch = FakeRunner([state(false), CommandResult(status: 0, output: ""), state(false)])
        do {
            _ = try SleepControl(runner: mismatch).setDisabled(true)
            fatalError("Unconfirmed setting accepted")
        } catch SleepControlError.verificationFailed {
            check(true, "Reject success when system setting did not change")
        }

        let readFailure = FakeRunner([CommandResult(status: 1, output: "Read failed")])
        do {
            _ = try SleepControl(runner: readFailure).setDisabled(true)
            fatalError("Write attempted with unknown state")
        } catch SleepControlError.commandFailed {
            check(readFailure.calls.count == 1, "Avoid writes when initial state cannot be read")
        }

        let authorization = OneClickAuthorization(userID: 501)
        check(authorization.rule == "#501 ALL = (root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1", "Grant only the two exact commands to this UID")
        check(!authorization.rule.contains("*") && !authorization.rule.contains("NOPASSWD: ALL"), "Never grant unrestricted passwordless sudo")
        let installScript = authorization.rootScript(enable: true)
        check(installScript.contains("/usr/sbin/visudo -cf \"$temporary\"") && installScript.contains("/bin/chmod 0440"), "Validate root-owned authorization before installing")
        check(installScript.contains("includedir") && installScript.contains("Refusing to replace"), "Check sudoers inclusion and reject unexpected files")
        let removeScript = authorization.rootScript(enable: false)
        check(removeScript.contains("/bin/rm -f \"$target\"") && !removeScript.contains("/bin/mv"), "Remove only the app's marked authorization file")
        let ruleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/test-sudoers")
        try (authorization.marker + "\n" + authorization.rule + "\n").write(to: ruleURL, atomically: true, encoding: .utf8)
        let syntax = try SystemCommandRunner().run("/usr/sbin/visudo", arguments: ["-cf", ruleURL.path])
        check(syntax.status == 0, "Real visudo accepts the restricted numeric UID rule")
        let scriptURL = ruleURL.deletingLastPathComponent().appendingPathComponent("test-setup.sh")
        for enable in [true, false] {
            try authorization.rootScript(enable: enable).write(to: scriptURL, atomically: true, encoding: .utf8)
            let syntax = try SystemCommandRunner().run("/bin/sh", arguments: ["-n", scriptURL.path])
            check(syntax.status == 0, "Setup \(enable ? "install" : "remove") shell syntax is valid")
        }

        let permissionRunner = FakeRunner([CommandResult(status: 0, output: "Allowed"), CommandResult(status: 0, output: "Allowed")])
        try OneClickAuthorization(runner: permissionRunner).verifyAccess()
        check(permissionRunner.calls.map { $0.1 } == ["0", "1"].map { ["-n", "-k", "-l", "--", "/usr/bin/pmset", "-a", "disablesleep", $0] }, "Check effective permission for both commands without executing them")
        let permissionDenied = FakeRunner([CommandResult(status: 1, output: "Rule invalid")])
        do { try OneClickAuthorization(runner: permissionDenied).verifyAccess(); fatalError("Expected permission failure") }
        catch SleepControlError.oneClickUnavailable { check(true, "Detect a broken rule before enabling persistent sleep prevention") }
        let start = Date()
        do {
            _ = try SystemCommandRunner(timeout: 0.1).run("/bin/sleep", arguments: ["10"])
            fatalError("Expected timeout")
        } catch SleepControlError.commandTimedOut {
            check(Date().timeIntervalSince(start) < 4, "Hung subprocess is terminated within bounded time")
        }
        let largeOutput = try SystemCommandRunner().run("/usr/bin/head", arguments: ["-c", "200000", "/dev/zero"])
        check(largeOutput.status == 0 && largeOutput.output.utf8.count == 200000, "Large subprocess output cannot deadlock a full pipe")
        check(removeScript.contains("/usr/bin/pmset -a disablesleep 0"), "Revocation restores normal sleep before deleting the rule")

        // Exercise the real subprocess reader without altering power settings.
        let liveState = try SleepControl().readState()
        check(true, "Read this Mac's live setting: \(liveState ? "ON" : "OFF")")
        print("\(passed) checks passed. No power settings were changed.")
    }
}
