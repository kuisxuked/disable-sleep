import Foundation

struct AutomationCommand: Equatable, Sendable {
    enum Action: String, Sendable { case on, off, toggle }
    let action: Action
    let minutes: Int?

    static let usage = """
    LidOff [--show | --quit | --status | --help]
    LidOff --on [--minutes 1...10080]
    LidOff --off
    LidOff --toggle
    Commands use the running app, including its safety guards and authorization UI.
    """

    static func parse(_ arguments: [String]) throws -> AutomationCommand? {
        if arguments.isEmpty || arguments.allSatisfy({ ["--show", "--quit", "--demo", "--diagnose-position"].contains($0) }) { return nil }
        guard let first = arguments.first,
              let action = Action(rawValue: String(first.dropFirst(2))), first.hasPrefix("--") else { throw AutomationError.invalidArguments }
        if arguments.count == 1 { return AutomationCommand(action: action, minutes: nil) }
        guard action == .on, arguments.count == 3, arguments[1] == "--minutes",
              let minutes = Int(arguments[2]), (1...10080).contains(minutes) else { throw AutomationError.invalidArguments }
        return AutomationCommand(action: action, minutes: minutes)
    }

    init(action: Action, minutes: Int?) { self.action = action; self.minutes = minutes }

    init?(userInfo: [AnyHashable: Any]?) {
        guard let raw = userInfo?["action"] as? String, let action = Action(rawValue: raw) else { return nil }
        let minutes = userInfo?["minutes"] as? Int
        guard userInfo?["minutes"] == nil || minutes != nil else { return nil }
        guard minutes == nil || (action == .on && (1...10080).contains(minutes!)) else { return nil }
        self.init(action: action, minutes: minutes)
    }

    var userInfo: [String: Any] {
        var result: [String: Any] = ["action": action.rawValue]
        if let minutes { result["minutes"] = minutes }
        return result
    }
}

enum AutomationError: Error { case invalidArguments }
