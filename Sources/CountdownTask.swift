import Foundation

struct CountdownTask: Codable, Equatable, Sendable {
    let deadline: Date
    let disableSleep: Bool
    var failed = false

    init(minutes: Int, disableSleep: Bool, now: Date = Date()) throws {
        guard (1...10080).contains(minutes) else {
            throw CountdownError.invalidMinutes
        }
        self.deadline = now.addingTimeInterval(Double(minutes) * 60)
        self.disableSleep = disableSleep
    }

    func secondsRemaining(at now: Date) -> Int {
        max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }

    func isDue(at now: Date) -> Bool { !failed && deadline <= now }

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
