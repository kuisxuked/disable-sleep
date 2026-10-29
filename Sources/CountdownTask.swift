import Foundation

struct CountdownTask: Codable, Equatable, Sendable {
    private(set) var deadline: Date
    let disableSleep: Bool
    var failed = false
    private(set) var pausedRemaining: TimeInterval?

    static let maximumSeconds: TimeInterval = 10080 * 60

    var isPaused: Bool { pausedRemaining != nil }

    init(minutes: Int, disableSleep: Bool, now: Date = Date()) throws {
        guard (1...10080).contains(minutes) else {
            throw CountdownError.invalidMinutes
        }
        self.deadline = now.addingTimeInterval(Double(minutes) * 60)
        self.disableSleep = disableSleep
    }

    private enum CodingKeys: String, CodingKey { case deadline, disableSleep, failed, pausedRemaining }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deadline = try values.decode(Date.self, forKey: .deadline)
        disableSleep = try values.decode(Bool.self, forKey: .disableSleep)
        failed = try values.decodeIfPresent(Bool.self, forKey: .failed) ?? false
        pausedRemaining = try values.decodeIfPresent(TimeInterval.self, forKey: .pausedRemaining)
        // Allow historical dates for overdue timers, but reject non-finite and
        // implausible dates before they can reach formatting or arithmetic.
        let timestamp = deadline.timeIntervalSince1970
        guard timestamp.isFinite, timestamp >= 0, deadline.timeIntervalSinceNow <= Self.maximumSeconds + 300,
              pausedRemaining.map({ $0.isFinite && (0...Self.maximumSeconds).contains($0) }) ?? true else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid countdown state"))
        }
        if failed { pausedRemaining = nil } // Repair legacy failed + paused tasks.
    }

    func secondsRemaining(at now: Date) -> Int {
        let seconds = pausedRemaining ?? deadline.timeIntervalSince(now)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(ceil(min(Self.maximumSeconds, seconds)))
    }

    mutating func pause(at now: Date) {
        guard !isPaused, !failed else { return }
        let seconds = deadline.timeIntervalSince(now)
        pausedRemaining = seconds.isFinite ? min(Self.maximumSeconds, max(0, seconds)) : 0
    }

    mutating func resume(at now: Date) {
        guard let pausedRemaining else { return }
        deadline = now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
    }

    func isDue(at now: Date) -> Bool { !failed && !isPaused && deadline <= now }

    func remainingText(at now: Date) -> String {
        let seconds = secondsRemaining(at: now)
        if seconds >= 3600 {
            return String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum CountdownError: LocalizedError {
    case invalidMinutes
    var errorDescription: String? { AppLanguage.current.text("请输入 1–10080 分钟。", "Enter 1–10080 minutes.") }
}
