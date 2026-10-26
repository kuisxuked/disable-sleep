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
        precondition(model.countdown?.isPaused == true)
        print("PASS: A new timer stays paused while Disable Sleep is off")
        model.toggle(true)
        precondition(model.countdown?.isPaused == false && model.disabled == true)
        print("PASS: Turning Disable Sleep on resumes the pending timer")
        model.toggle(false)
        precondition(model.countdown?.isPaused == true && model.disabled == false)
        let frozen = model.countdown!.secondsRemaining(at: Date())
        precondition(model.countdown!.secondsRemaining(at: Date().addingTimeInterval(7200)) == frozen)
        print("PASS: Turning Disable Sleep off freezes the countdown")
        model.refresh()
        precondition(model.countdown?.isPaused == true)
        print("PASS: Reopening the panel keeps an off-state timer paused")
        model.toggle(true)
        precondition(model.countdown?.isPaused == false && model.countdown!.secondsRemaining(at: Date()) == frozen)
        print("PASS: Turning it back on continues from the frozen remaining time")
        model.keepAwakeIndefinitely()
        precondition(model.countdown == nil && model.disabled == true)
        print("PASS: Never clears the timer and keeps sleep disabled")
        model.toggle(false)
        precondition(model.countdown == nil && model.disabled == false)
        print("PASS: The main switch restores normal sleep after Never")
        precondition(AppLanguage.chinese.text("永不", "Never") == "永不")
        precondition(AppLanguage.english.text("永不", "Never") == "Never")
        print("PASS: Chinese and English label selection")
        print("9 model checks passed in isolated demo state; power settings were not changed.")
    }
}
