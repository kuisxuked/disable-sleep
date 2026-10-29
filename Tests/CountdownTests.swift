import Foundation

@main
struct CountdownTests {
    static func main() throws {
        let now = Date()
        var passed = 0
        func check(_ condition: Bool, _ label: String) {
            precondition(condition, label)
            passed += 1
            print("PASS: \(label)")
        }
        let task = try CountdownTask(minutes: 30, disableSleep: true, now: now)
        check(task.deadline == now.addingTimeInterval(1800) && task.disableSleep, "30-minute countdown uses an absolute deadline and intended action")
        check(task.remainingText(at: now) == "30:00", "Display remaining minutes")
        check(task.secondsRemaining(at: now.addingTimeInterval(0.2)) == 1800, "Round remaining time up instead of firing early")
        check(!task.isDue(at: now.addingTimeInterval(1799.9)), "Do not fire before deadline")
        check(task.isDue(at: task.deadline), "Fire exactly at deadline")
        check(task.isDue(at: now.addingTimeInterval(7200)), "Catch up a timer overdue after sleep or relaunch")
        check(task.remainingText(at: now.addingTimeInterval(7200)) == "00:00", "Never display a negative countdown")
        let longTask = try CountdownTask(minutes: 90, disableSleep: false, now: now)
        check(longTask.remainingText(at: now) == "1:30:00" && !longTask.disableSleep, "Support longer countdowns and restoring sleep")
        let restored = try JSONDecoder().decode(CountdownTask.self, from: JSONEncoder().encode(task))
        check(restored == task, "Persist deadline and action across app restarts")
        var paused = task
        paused.pause(at: now.addingTimeInterval(75.25))
        check(paused.isPaused && paused.secondsRemaining(at: now.addingTimeInterval(7200)) == 1725, "Paused countdown freezes its remaining time")
        check(!paused.isDue(at: now.addingTimeInterval(7200)), "Paused countdown never fires while sleep is allowed")
        let frozen = paused
        paused.pause(at: now.addingTimeInterval(1000))
        check(paused == frozen, "Repeated refresh while off does not consume or reset remaining time")
        var reloaded = try JSONDecoder().decode(CountdownTask.self, from: JSONEncoder().encode(paused))
        check(reloaded.isPaused && reloaded.secondsRemaining(at: now.addingTimeInterval(86400)) == 1725, "Paused state survives relaunch without counting downtime")
        let resumeTime = now.addingTimeInterval(7200)
        reloaded.resume(at: resumeTime)
        check(!reloaded.isPaused && reloaded.deadline == resumeTime.addingTimeInterval(1724.75), "Resume preserves fractional remaining time at a new deadline")
        let resumedDeadline = reloaded.deadline
        reloaded.resume(at: resumeTime.addingTimeInterval(50))
        check(reloaded.deadline == resumedDeadline, "Repeated refresh while on does not extend the timer")
        check(!reloaded.isDue(at: resumedDeadline.addingTimeInterval(-0.01)) && reloaded.isDue(at: resumedDeadline), "Resumed timer fires only at its adjusted deadline")
        let legacyData = try JSONSerialization.data(withJSONObject: ["deadline": task.deadline.timeIntervalSinceReferenceDate, "disableSleep": true, "failed": false])
        let legacy = try JSONDecoder().decode(CountdownTask.self, from: legacyData)
        check(!legacy.isPaused && legacy.deadline == task.deadline, "Existing v1.4.0 timers migrate without data loss")
        var failed = task
        failed.failed = true
        let restoredFailure = try JSONDecoder().decode(CountdownTask.self, from: JSONEncoder().encode(failed))
        check(!restoredFailure.isDue(at: now.addingTimeInterval(7200)), "Failed timers do not repeatedly execute after relaunch")
        for minutes in [0, -1, 10081, Int.max] {
            do {
                _ = try CountdownTask(minutes: minutes, disableSleep: true, now: now)
                fatalError("Accepted invalid duration")
            } catch CountdownError.invalidMinutes {
                check(true, "Reject invalid duration \(minutes)")
            }
        }
        check(try CountdownTask(minutes: 10080, disableSleep: true, now: now).secondsRemaining(at: now) == 604800, "Accept the maximum seven-day countdown")
        for (key, value) in [("deadline", now.timeIntervalSinceReferenceDate + 605101), ("deadline", 1e300), ("deadline", -1e300), ("pausedRemaining", -1.0), ("pausedRemaining", 1e300), ("pausedRemaining", 604801.0)] {
            var record: [String: Any] = ["deadline": now.timeIntervalSinceReferenceDate, "disableSleep": false, "failed": false]
            record[key] = value
            let data = try JSONSerialization.data(withJSONObject: record)
            do { _ = try JSONDecoder().decode(CountdownTask.self, from: data); fatalError("Accepted corrupt timer") }
            catch DecodingError.dataCorrupted { check(true, "Reject corrupt \(key) = \(value)") }
        }
        check(task.secondsRemaining(at: Date(timeIntervalSince1970: -1e300)) == 604800, "Huge clock difference uses saturating integer conversion")
        check(task.secondsRemaining(at: Date(timeIntervalSince1970: 1e300)) == 0, "Huge overdue clock difference returns zero")
        var failedRetry = task
        failedRetry.failed = true
        failedRetry.pause(at: task.deadline.addingTimeInterval(60))
        check(!failedRetry.isPaused && failedRetry.failed, "A failed timer never auto-pauses and remains retryable")
        let legacyFailure: [String: Any] = ["deadline": now.timeIntervalSinceReferenceDate, "disableSleep": true, "failed": true, "pausedRemaining": 0]
        let repaired = try JSONDecoder().decode(CountdownTask.self, from: JSONSerialization.data(withJSONObject: legacyFailure))
        check(repaired.failed && !repaired.isPaused, "Repair saved legacy failed + paused timers for Retry")
        print("\(passed) countdown checks passed.")
    }
}
