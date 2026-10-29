import Foundation

@main
struct AutomationTests {
    static func main() throws {
        var passed = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); passed += 1; print("PASS: \(label)") }
        check(try AutomationCommand.parse(["--on", "--minutes", "30"]) == AutomationCommand(action: .on, minutes: 30), "CLI validates bounded keep-awake sessions")
        check(try AutomationCommand.parse(["--off"])?.action == .off, "CLI allows restoring sleep")
        check(try AutomationCommand.parse(["--toggle"])?.action == .toggle, "CLI allows toggling via the protected app")
        for args in [["--on", "--minutes", "0"], ["--on", "--minutes", "10081"], ["--on", "--minutes", "1e300"], ["--off", "--minutes", "30"], ["--on", "--demo"], ["--unknown"], ["--on", "--off"]] {
            do { _ = try AutomationCommand.parse(args); fatalError("Accepted invalid CLI arguments") }
            catch AutomationError.invalidArguments { check(true, "Reject invalid command \(args)") }
        }
        let request = AutomationCommand(action: .on, minutes: 30)
        check(AutomationCommand(userInfo: request.userInfo) == request, "IPC payload preserves validated action and duration")
        check(AutomationCommand(userInfo: ["action": "on", "minutes": "oops"]) == nil, "Malformed IPC duration cannot become an indefinite session")
        check(AutomationCommand(userInfo: ["action": "off", "minutes": 3]) == nil, "Reject inappropriate duration in IPC")
        print("\(passed) automation checks passed.")
    }
}
