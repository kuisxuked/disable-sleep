import Foundation
import Darwin
import ServiceManagement

protocol SessionProtecting: Sendable {
    func install() throws
    func setDisabled(_ disabled: Bool, deadline: Date?, policy: SafetyPolicy, now: Date) throws -> Bool
    func heartbeat(deadline: Date?, policy: SafetyPolicy, now: Date) throws -> SafetyStop?
    func lastStop() throws -> SafetyStop?
    func uninstall() throws
}

extension SessionProtecting {
    func setDisabled(_ disabled: Bool, deadline: Date?, policy: SafetyPolicy) throws -> Bool {
        try setDisabled(disabled, deadline: deadline, policy: policy, now: Date())
    }
    func heartbeat(deadline: Date?, policy: SafetyPolicy) throws -> SafetyStop? {
        try heartbeat(deadline: deadline, policy: policy, now: Date())
    }
}

/// Unprivileged watchdog. Its only elevated operation is the existing exact sudo command.
struct SafetyWatchdog: SessionProtecting {
    static let label = "local.lidoff.watchdog"
    let directory: URL
    let agentsDirectory: URL
    let runner: any CommandRunning
    let snapshot: @Sendable () -> PowerSnapshot

    init(directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LidOff"),
         agentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
         runner: any CommandRunning = SystemCommandRunner(), snapshot: @escaping @Sendable () -> PowerSnapshot = { .read() }) {
        self.directory = directory
        self.agentsDirectory = agentsDirectory
        self.runner = runner
        self.snapshot = snapshot
    }

    var stateURL: URL { directory.appendingPathComponent("session.json") }
    var executableURL: URL { directory.appendingPathComponent("LidOffWatchdog") }
    var plistURL: URL { agentsDirectory.appendingPathComponent(Self.label + ".plist") }
    var service: String { "gui/\(getuid())/\(Self.label)" }

    func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(directory.appendingPathComponent("session.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw SafetyStop.watchdogUnavailable }
        defer { close(fd) }
        let limit = ProcessInfo.processInfo.systemUptime + 2
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK, ProcessInfo.processInfo.systemUptime < limit else { throw SafetyStop.watchdogUnavailable }
            Thread.sleep(forTimeInterval: 0.02)
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    func readRecord() throws -> SafetyRecord {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return SafetyRecord() }
        return try JSONDecoder().decode(SafetyRecord.self, from: Data(contentsOf: stateURL))
    }

    func writeRecord(_ record: SafetyRecord) throws {
        try JSONEncoder().encode(record).write(to: stateURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    /// Called by launchd even when the UI app is gone. Keep the lease after a failed
    /// restore, so launchd retries; never turn sleep prevention on from this process.
    func check(now: Date = Date()) throws {
        do {
            try withLock {
                var record: SafetyRecord
                do { record = try readRecord() }
                catch {
                    _ = try SleepControl(runner: runner).setDisabled(false)
                    record = SafetyRecord(lastStop: .appUnavailable)
                }
                record.lastCheck = now
                if let session = record.session, let reason = session.stopReason(at: now, snapshot: snapshot()) {
                    _ = try SleepControl(runner: runner).setDisabled(false)
                    record.session = nil
                    record.lastStop = reason
                }
                try writeRecord(record)
            }
        } catch SafetyStop.watchdogUnavailable {
            // A frozen UI could hold the lock. Restoration is safe even without
            // the lock: only enabling requires serialized, persisted recovery.
            _ = try SleepControl(runner: runner).setDisabled(false)
            throw SafetyStop.watchdogUnavailable
        }
    }

    func install() throws {
        let fm = FileManager.default
        try LegacyMigration.retireWatchdog(runner: runner)
        guard let bundled = Bundle.main.url(forAuxiliaryExecutable: "LidOffWatchdog") else { throw SafetyStop.watchdogUnavailable }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.createDirectory(at: agentsDirectory, withIntermediateDirectories: true)
        let binary = try Data(contentsOf: bundled)
        let plist: [String: Any] = [
            "Label": Self.label, "ProgramArguments": [executableURL.path],
            "RunAtLoad": true, "StartInterval": 10, "ProcessType": "Background",
            "AssociatedBundleIdentifiers": ["local.lidoff.app"]
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let changed = (try? Data(contentsOf: executableURL)) != binary || (try? Data(contentsOf: plistURL)) != plistData
        if changed {
            _ = try runner.run("/bin/launchctl", arguments: ["bootout", service])
            try binary.write(to: executableURL, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executableURL.path)
            try plistData.write(to: plistURL, options: .atomic)
        }
        if try changed || (runner.run("/bin/launchctl", arguments: ["print", service])).status != 0 {
            try withLock {
                var record = try readRecord()
                record.lastCheck = nil
                try writeRecord(record)
            }
            let result = try runner.run("/bin/launchctl", arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
            guard result.status == 0 else { throw SleepControlError.commandFailed(result.output) }
        }
        // Check actual execution, not just registration. Disabled background items
        // must not leave the app believing it has crash protection.
        for _ in 0..<50 {
            let healthy = try withLock { try readRecord().lastCheck.map { abs($0.timeIntervalSinceNow) < 25 } ?? false }
            if healthy { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw SafetyStop.watchdogUnavailable
    }

    func setDisabled(_ disabled: Bool, deadline: Date?, policy: SafetyPolicy, now: Date = Date()) throws -> Bool {
        try withLock {
            var record = try readRecord()
            if disabled {
                guard let checked = record.lastCheck, abs(checked.timeIntervalSince(now)) < 25 else { throw SafetyStop.watchdogUnavailable }
                if let reason = policy.stopReason(for: snapshot()) { throw reason }
                if let deadline, deadline <= now { throw SafetyStop.deadline }
                record.session = SafetySession(heartbeat: now, deadline: deadline, policy: policy)
                record.lastStop = nil
                // Persist recovery information BEFORE setting persistent system state.
                try writeRecord(record)
            }
            let actual = try SleepControl(runner: runner).setDisabled(disabled)
            if !disabled { record.session = nil; record.lastStop = nil; try writeRecord(record) }
            return actual
        }
    }

    /// Returns a stop reason after the watchdog has ended the session. Never
    /// recreate a missing lease here: that could resurrect a stopped session.
    func heartbeat(deadline: Date?, policy: SafetyPolicy, now: Date = Date()) throws -> SafetyStop? {
        try withLock {
            var record = try readRecord()
            guard var session = record.session else {
                _ = try SleepControl(runner: runner).setDisabled(false)
                record.lastStop = record.lastStop ?? .appUnavailable
                try writeRecord(record)
                return record.lastStop
            }
            let reason: SafetyStop?
            if record.lastCheck.map({ abs($0.timeIntervalSince(now)) >= 35 }) ?? true {
                reason = .watchdogUnavailable
            } else {
                reason = session.stopReason(at: now, snapshot: snapshot())
            }
            if let reason {
                _ = try SleepControl(runner: runner).setDisabled(false)
                record.session = nil
                record.lastStop = reason
                try writeRecord(record)
                return reason
            }
            session.heartbeat = now
            session.deadline = deadline
            session.policy = policy
            // Apply policy changes immediately, including a newly enabled AC guard.
            if let reason = policy.stopReason(for: snapshot()) {
                _ = try SleepControl(runner: runner).setDisabled(false)
                record.session = nil
                record.lastStop = reason
                try writeRecord(record)
                return reason
            }
            record.session = session
            try writeRecord(record)
            return nil
        }
    }

    func lastStop() throws -> SafetyStop? { try withLock { try readRecord().lastStop } }

    func uninstall() throws {
        let result = try runner.run("/bin/launchctl", arguments: ["bootout", service])
        if try result.status != 0 && (runner.run("/bin/launchctl", arguments: ["print", service])).status == 0 {
            throw SleepControlError.commandFailed(result.output)
        }
        if FileManager.default.fileExists(atPath: plistURL.path) { try FileManager.default.removeItem(at: plistURL) }
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
}
