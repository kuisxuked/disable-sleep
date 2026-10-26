import Foundation

@main
@MainActor
struct ModelTests {
    static func main() {
        let model = SleepModel(demo: true)
        model.activate()
        model.startCountdown(minutes: 30, target: false)
        precondition(model.countdown != nil)
        print("PASS: Starting a countdown creates a pending task")
        model.toggle(true)
        precondition(model.countdown != nil && model.disabled == true)
        print("PASS: A manual switch leaves the chosen countdown in place")
        model.keepAwakeIndefinitely()
        precondition(model.countdown == nil && model.disabled == true)
        print("PASS: Never clears the timer and keeps sleep disabled")
        model.toggle(false)
        precondition(model.countdown == nil && model.disabled == false)
        print("PASS: The main switch restores normal sleep after Never")
        precondition(AppLanguage.chinese.text("永不", "Never") == "永不")
        precondition(AppLanguage.english.text("永不", "Never") == "Never")
        print("PASS: Chinese and English label selection")
        print("5 model checks passed in isolated demo state; power settings were not changed.")
    }
}
