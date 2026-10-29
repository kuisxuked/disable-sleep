import Foundation
import UserNotifications

struct SessionNotifications {
    static let identifier = "LidOff.countdown.warning"

    static func synchronize(task: CountdownTask?, enabled: Bool) {
        guard Bundle.main.bundleIdentifier == "local.lidoff.app" else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled, let task, !task.disableSleep, !task.failed, !task.isPaused else { return }
        let delay = task.deadline.timeIntervalSinceNow - 60
        guard delay > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "LidOff"
        content.body = AppLanguage.current.text("还有 1 分钟恢复正常睡眠。", "Normal sleep will be restored in one minute.")
        center.add(UNNotificationRequest(identifier: identifier, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)))
    }
}
