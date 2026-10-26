import AppKit
import SwiftUI

@MainActor
final class SleepModel: ObservableObject {
    @Published private(set) var disabled: Bool?
    @Published private(set) var busy = false
    @Published private(set) var countdown: CountdownTask?
    @Published private(set) var remaining = ""
    @Published var message: String?
    var onChange: (() -> Void)?
    private let control = SleepControl()
    private let authorization = OneClickAuthorization()
    private var ticker: Timer?
    private let storageKey = "DisableSleep.countdown.v1"
    private let demo: Bool

    init(demo: Bool = false) {
        self.demo = demo
        if demo { disabled = false; return }
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            countdown = try? JSONDecoder().decode(CountdownTask.self, from: data)
        }
    }

    func activate() {
        refresh()
        updateTicker()
        tick()
    }

    func refresh() {
        guard !busy else { return }
        if !demo { disabled = try? control.readState() }
        onChange?()
        tick()
    }

    func toggle(_ target: Bool) { execute(target, scheduled: false) }

    func startCountdown(minutes: Int, target: Bool) {
        guard !busy else { return }
        do { _ = try CountdownTask(minutes: minutes, disableSleep: target) }
        catch { message = error.localizedDescription; return }
        if demo {
            countdown = try? CountdownTask(minutes: minutes, disableSleep: target)
            updateTicker()
            tick()
            return
        }
        busy = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async { [authorization] in
            let result = Result {
                if !authorization.isInstalled { try authorization.configure(enable: true) }
                return try CountdownTask(minutes: minutes, disableSleep: target)
            }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let task):
                    self.countdown = task
                    self.persistCountdown()
                    self.updateTicker()
                    self.tick()
                case .failure(let error): self.report(error)
                }
            }
        }
    }

    func cancelCountdown() {
        guard !busy else { return }
        countdown = nil
        message = nil
        persistCountdown()
        updateTicker()
    }

    func keepAwakeIndefinitely() {
        guard !busy else { return }
        cancelCountdown()
        execute(true, scheduled: false)
    }

    func retryCountdown() {
        guard let task = countdown, task.failed, !busy else { return }
        execute(task.disableSleep, scheduled: true)
    }

    private func execute(_ target: Bool, scheduled: Bool) {
        guard !busy, disabled != nil || scheduled else { return }
        if demo {
            disabled = target
            if scheduled { countdown = nil; updateTicker() }
            onChange?()
            return
        }
        busy = true
        message = nil
        onChange?()
        DispatchQueue.global(qos: .userInitiated).async { [control, authorization] in
            let result = Result {
                // Unattended timers never open an authorization prompt.
                if !scheduled && !authorization.isInstalled {
                    try authorization.configure(enable: true)
                }
                return try control.setDisabled(target)
            }
            let latest = try? control.readState()
            DispatchQueue.main.async {
                self.busy = false
                self.disabled = latest
                switch result {
                case .success(let value):
                    self.disabled = value
                    if scheduled { self.countdown = nil }
                case .failure(let error):
                    if scheduled { self.countdown?.failed = true }
                    self.report(error)
                }
                if scheduled { self.persistCountdown(); self.updateTicker() }
                self.onChange?()
                self.tick()
            }
        }
    }

    private func report(_ error: Error) {
        if case SleepControlError.cancelled = error { return }
        message = error.localizedDescription
    }

    private func persistCountdown() {
        guard !demo else { return }
        if let countdown, let data = try? JSONEncoder().encode(countdown) {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private func updateTicker() {
        ticker?.invalidate()
        ticker = nil
        guard let task = countdown, !task.failed else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let task = countdown else { remaining = ""; return }
        remaining = task.remainingText(at: Date())
        if task.isDue(at: Date()), !busy { execute(task.disableSleep, scheduled: true) }
    }
}

struct SleepPanel: View {
    @ObservedObject var model: SleepModel
    @AppStorage("DisableSleep.language") private var language = AppLanguage.systemDefault.rawValue
    @State private var minutes = "30"
    @State private var target = false

    init(model: SleepModel, minutes: String = "30", target: Bool = false) {
        self.model = model
        self._minutes = State(initialValue: minutes)
        self._target = State(initialValue: target)
    }

    private var lang: AppLanguage { AppLanguage(rawValue: language) ?? .systemDefault }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Disable Sleep").font(.system(size: 14, weight: .semibold))
                Button(lang == .chinese ? "中" : "EN") {
                    language = lang == .chinese ? AppLanguage.english.rawValue : AppLanguage.chinese.rawValue
                    model.message = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 16)
                .help(lang.text("Switch to English", "切换到中文"))
                .accessibilityLabel(lang.text("Switch to English", "切换到中文"))
                Spacer()
                if model.busy {
                    ProgressView().controlSize(.small)
                } else {
                    Toggle("Disable Sleep", isOn: Binding(get: { model.disabled ?? false }, set: { model.toggle($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(model.disabled == nil)
                        .accessibilityLabel("Disable Sleep")
                }
            }
            Divider()
            if let task = model.countdown {
                HStack(spacing: 8) {
                    Image(systemName: "timer").foregroundStyle(.secondary)
                    Text(task.failed ? lang.text("执行失败", "Failed") : model.remaining)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Text(task.disableSleep ? lang.text("禁止睡眠", "Keep awake") : lang.text("恢复睡眠", "Allow sleep"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if task.failed {
                        Button(action: model.retryCountdown) { Image(systemName: "arrow.clockwise") }
                            .help(lang.text("重试", "Retry"))
                    }
                    Button(action: model.cancelCountdown) { Image(systemName: "xmark.circle.fill") }
                        .help(lang.text("取消定时", "Cancel timer"))
                }
                .buttonStyle(.plain)
                .disabled(model.busy)
            } else {
                HStack(spacing: 7) {
                    DurationField(value: $minutes, language: lang)
                        .frame(width: 62, height: 22)
                    if minutes == "never" {
                        Text(lang.text("自动恢复睡眠", "restore sleep"))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button(lang.text("开启", "Start"), action: model.keepAwakeIndefinitely)
                            .buttonStyle(.bordered)
                    } else {
                        Text(lang.text("分钟后", "min later")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Picker(lang.text("定时操作", "Timer action"), selection: $target) {
                            Text(lang.text("禁止睡眠", "Keep awake")).tag(true)
                            Text(lang.text("恢复睡眠", "Allow sleep")).tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        Button(lang.text("开始", "Start")) { model.startCountdown(minutes: Int(minutes.trimmingCharacters(in: .whitespaces)) ?? 0, target: target) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .disabled(model.busy)
            }
            if let message = model.message {
                Text(message).font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = SleepModel(demo: CommandLine.arguments.contains("--demo"))
    private var notificationPrefix: String { Bundle.main.bundleIdentifier ?? "local.disablesleep.app" }
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.disablesleep.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            let name = notificationPrefix + (CommandLine.arguments.contains("--quit") ? ".quit" : ".show")
            DistributedNotificationCenter.default().postNotificationName(.init(name), object: nil)
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--quit") { NSApp.terminate(nil); return }

        // AppKit otherwise inserts a new item at the far left, which can sit
        // behind a MacBook's camera housing. Seed its autosaved right-side slot
        // once, then preserve any position chosen later with Command-drag.
        let defaults = UserDefaults.standard
        let positionKey = "NSStatusItem Preferred Position DisableSleep"
        let placementKey = "DisableSleep.rightSidePlacement.v1"
        if !defaults.bool(forKey: placementKey) || defaults.object(forKey: positionKey) == nil {
            defaults.set(0, forKey: positionKey)
            defaults.set(true, forKey: placementKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "DisableSleep"
        statusItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: SleepPanel(model: model))
        model.onChange = { [weak self] in self?.updateIcon() }
        model.activate()

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showPopover), name: .init(notificationPrefix + ".show"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(quit), name: .init(notificationPrefix + ".quit"), object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.async { self.showPopover() }
        }
        if CommandLine.arguments.contains("--diagnose-position") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let window = self.statusItem.button?.window,
                      let screen = window.screen ?? NSScreen.main else { return }
                let report: [String: Any] = [
                    "visible": self.statusItem.isVisible,
                    "iconFrame": NSStringFromRect(window.frame),
                    "screenFrame": NSStringFromRect(screen.frame),
                    // A status-item window extends slightly below the bar;
                    // only horizontal bounds determine overlap with the notch.
                    "rightOfNotch": screen.auxiliaryTopRightArea.map {
                        window.frame.minX >= $0.minX && window.frame.maxX <= $0.maxX
                    } ?? true,
                    "rightMenuBarArea": screen.auxiliaryTopRightArea.map { NSStringFromRect($0) } ?? "no notch"
                ]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: .sortedKeys) {
                    print(String(decoding: data, as: UTF8.self))
                    fflush(stdout)
                }
            }
        }
    }

    private func updateIcon() {
        let symbol = model.disabled == true ? "sun.max.fill" : model.disabled == false ? "moon.zzz" : "laptopcomputer"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Disable Sleep")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = model.disabled == true ? "Disable Sleep: On" : model.disabled == false ? "Disable Sleep: Off" : "Disable Sleep"
        statusItem.button?.setAccessibilityLabel(statusItem.button?.toolTip)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    @objc private func refresh() { model.refresh() }
    @objc private func showPopover() {
        guard let button = statusItem.button else { return }
        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func togglePopover() {
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

#if !DEMO_EXPORT
@main
struct DisableSleepApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

#endif
