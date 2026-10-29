import Foundation
import Darwin

struct CommandResult: Sendable {
    let status: Int32
    let output: String
}

protocol CommandRunning: Sendable {
    func run(_ executable: String, arguments: [String]) throws -> CommandResult
}

struct SystemCommandRunner: CommandRunning {
    var timeout: TimeInterval?

    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        // A file avoids pipe deadlocks if a child emits more than a pipe buffer.
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("lidoff-command-" + UUID().uuidString)
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw SleepControlError.commandFailed("Could not create command output file.")
        }
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let output = try FileHandle(forUpdating: outputURL)
        defer { try? output.close() }
        let finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        let limit = max(0.1, timeout ?? (executable == "/usr/bin/osascript" ? 120 : 10))
        if finished.wait(timeout: .now() + limit) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw SleepControlError.commandTimedOut
        }
        process.waitUntilExit()
        try output.seek(toOffset: 0)
        let data = try output.read(upToCount: 1_048_576) ?? Data()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

enum SleepControlError: LocalizedError {
    case commandTimedOut
    case cancelled
    case commandFailed(String)
    case unreadableState
    case verificationFailed
    case configurationFailed
    case oneClickUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .commandTimedOut: return AppLanguage.current.text("操作超时，请重试。", "The operation timed out. Try again.")
        case .cancelled: return AppLanguage.current.text("已取消授权，未做更改。", "Authorization cancelled. No changes were applied.")
        case .commandFailed(let message): return AppLanguage.current.text("macOS 无法完成更改。", "macOS could not complete the change.") + " " + message
        case .unreadableState: return AppLanguage.current.text("无法读取睡眠设置，请重新打开面板。", "Could not read the sleep setting. Reopen the panel.")
        case .verificationFailed: return AppLanguage.current.text("未能确认设置，请重试。", "macOS did not confirm the requested setting. Try again.")
        case .configurationFailed: return AppLanguage.current.text("未能确认免密授权，请重试。", "Could not confirm one-click setup. Try again.")
        case .oneClickUnavailable(let detail): return AppLanguage.current.text("免密授权不可用，请查看 README 中的授权说明。", "One-click access is unavailable. See “What does the one-time authorization permit?” in the README.") + " " + detail
        }
    }
}

struct SleepControl: Sendable {
    let runner: any CommandRunning

    init(runner: any CommandRunning = SystemCommandRunner()) {
        self.runner = runner
    }

    static func parseState(_ output: String) throws -> Bool {
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            if parts.first == "SleepDisabled" {
                guard parts.count == 2 else { throw SleepControlError.unreadableState }
                if parts[1] == "1" { return true }
                if parts[1] == "0" { return false }
                throw SleepControlError.unreadableState
            }
        }
        // Fresh Macs may omit the key until pmset has explicitly set it once.
        // Only infer the default from a recognizable, successful pmset response.
        if output.contains("Currently in use:"), output.split(whereSeparator: \.isNewline).contains(where: {
            let parts = $0.split(whereSeparator: \.isWhitespace)
            return parts.count >= 2 && parts[0] == "sleep" && Int(parts[1]) != nil
        }) { return false }
        throw SleepControlError.unreadableState
    }

    func readState() throws -> Bool {
        let result = try runner.run("/usr/bin/pmset", arguments: ["-g"])
        guard result.status == 0 else {
            throw SleepControlError.commandFailed(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return try Self.parseState(result.output)
    }

    func setDisabled(_ disabled: Bool) throws -> Bool {
        if try readState() == disabled { return disabled }
        // -n never prompts. -k ignores cached credentials, so this works only
        // through a genuine passwordless rule, including immediately after reboot.
        let result = try runner.run("/usr/bin/sudo", arguments: ["-n", "-k", "--", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"])
        guard result.status == 0 else {
            throw SleepControlError.oneClickUnavailable(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let actual = try readState()
        guard actual == disabled else { throw SleepControlError.verificationFailed }
        return actual
    }
}
