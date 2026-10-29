import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications

@MainActor
final class SleepModel: ObservableObject {
    @Published private(set) var disabled: Bool?
    @Published private(set) var busy = false
    @Published private(set) var countdown: CountdownTask?
    @Published private(set) var remaining = ""
    @Published var message: String?
    @Published var keepDisplayAwake = UserDefaults.standard.bool(forKey: "LidOff.keepDisplayAwake")
    @Published var preventIdleLock = false
    @Published var stopInLowPowerMode = false
    @Published var onlyOnAC = UserDefaults.standard.bool(forKey: "LidOff.onlyOnAC")
    @Published var batteryThreshold = UserDefaults.standard.object(forKey: "LidOff.batteryThreshold") as? Int ?? 20
    @Published private(set) var launchAtLogin = false
    @Published private(set) var notifyBeforeEnd = false
    @Published private(set) var shortcutEnabled = false
    var onShortcutPreferenceChanged: ((Bool) throws -> Void)?
    var onChange: (() -> Void)?
    private let control: SleepControl
    private let authorization: any Authorizing
    private let watchdog: any SessionProtecting
    private let defaults: UserDefaults
    private let authorizationConfirmation: (() -> Bool)?
    private let display: DisplaySleep
    private var ticker: Timer?
    private var lastPoll: TimeInterval = -5
    private var ownsSession = false
    private let storageKey = "LidOff.countdown.v1"
    private let demo: Bool
    private var policy: SafetyPolicy { SafetyPolicy(batteryThreshold: batteryThreshold, onlyOnAC: onlyOnAC, stopInLowPowerMode: stopInLowPowerMode) }
    private var safetyDeadline: Date? {
        guard let task = countdown, !task.disableSleep, !task.isPaused else { return nil }
        return task.deadline
    }

    init(demo: Bool = false, control: SleepControl = SleepControl(),
         authorization: any Authorizing = OneClickAuthorization(), watchdog: any SessionProtecting = SafetyWatchdog(),
         defaults: UserDefaults = .standard, authorizationConfirmation: (() -> Bool)? = nil,
         display: DisplaySleep? = nil) {
        self.demo = demo
        self.control = control
        self.authorization = authorization
        self.watchdog = watchdog
        self.defaults = defaults
        self.display = display ?? DisplaySleep()
        self.keepDisplayAwake = defaults.bool(forKey: "LidOff.keepDisplayAwake")
        self.preventIdleLock = defaults.bool(forKey: "LidOff.preventIdleLock")
        self.stopInLowPowerMode = defaults.bool(forKey: "LidOff.stopInLowPowerMode")
        self.onlyOnAC = defaults.bool(forKey: "LidOff.onlyOnAC")
        let threshold = defaults.integer(forKey: "LidOff.batteryThreshold")
        self.batteryThreshold = [10, 15, 20, 25, 30, 40, 50].contains(threshold) ? threshold : 20
        self.authorizationConfirmation = authorizationConfirmation
        self.shortcutEnabled = defaults.bool(forKey: "LidOff.shortcutEnabled")
        self.notifyBeforeEnd = defaults.bool(forKey: "LidOff.notifyBeforeEnd")
        if demo { disabled = false; return }
        if let data = defaults.data(forKey: storageKey) {
            countdown = try? JSONDecoder().decode(CountdownTask.self, from: data)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func activate() {
        if !demo, let stop = try? watchdog.lastStop() { handleStop(stop) }
        refresh()
        if !demo, disabled == true { execute(true, scheduled: false) }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
    }

    func refresh() {
        guard !busy else { return }
        if !demo {
            do { disabled = try control.readState() }
            catch { report(error) }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            maintainSession()
        }
        synchronizeCountdown()
        updateDisplay()
        onChange?()
    }

    func toggle(_ target: Bool) { execute(target, scheduled: false) }

    func apply(_ command: AutomationCommand) {
        guard !busy else {
            message = AppLanguage.current.text("操作进行中，请稍后重试。", "An operation is in progress. Retry when it finishes.")
            return
        }
        switch command.action {
        case .off: toggle(false)
        case .toggle: if let disabled { toggle(!disabled) }
        case .on:
            if let minutes = command.minutes { startCountdown(minutes: minutes, target: false) }
            else { cancelCountdown() }
            toggle(true)
        }
    }

    func startCountdown(minutes: Int, target: Bool) {
        guard !busy else { return }
        do {
            var task = try CountdownTask(minutes: minutes, disableSleep: target)
            if disabled != true { task.pause(at: Date()) }
            if !demo, ownsSession {
                if let reason = try watchdog.heartbeat(deadline: target ? nil : task.deadline, policy: policy) {
                    handleStop(reason); return
                }
            }
            countdown = task
            message = nil
            persistCountdown()
            tick()
        } catch { report(error) }
    }

    func cancelCountdown() {
        guard !busy else { return }
        countdown = nil
        remaining = ""
        message = nil
        persistCountdown()
        if !demo { maintainSession() }
    }

    func keepAwakeIndefinitely() {
        guard !busy else { return }
        cancelCountdown()
        execute(true, scheduled: false)
    }

    func retryCountdown() {
        guard let task = countdown, task.failed, !task.isPaused, !busy else { return }
        execute(task.disableSleep, scheduled: true)
    }

    private func execute(_ target: Bool, scheduled: Bool) {
        guard !busy, disabled != nil || scheduled else { return }
        if !demo, !scheduled, !authorization.isInstalled, !confirmAuthorization() { return }
        if demo {
            disabled = target
            if scheduled { countdown = nil }
            synchronizeCountdown()
            tick()
            onChange?()
            return
        }
        busy = true
        message = nil
        onChange?()
        let pending = countdown
        let policy = policy
        DispatchQueue.global(qos: .userInitiated).async { [control, authorization, watchdog] in
            let result = Result { () -> (Bool, CountdownTask?) in
                if !scheduled && !authorization.isInstalled { try authorization.configure(enable: true) }
                if target { try authorization.verifyAccess(); try watchdog.install() }
                var task = pending
                if target { task?.resume(at: Date()) }
                let deadline = task.flatMap { !$0.disableSleep && !$0.isPaused ? $0.deadline : nil }
                let actual = try watchdog.setDisabled(target, deadline: deadline, policy: policy)
                return (actual, task)
            }
            let latest = try? control.readState()
            DispatchQueue.main.async {
                self.busy = false
                self.disabled = latest
                switch result {
                case .success(let (value, task)):
                    self.disabled = value
                    self.ownsSession = value
                    self.countdown = scheduled ? nil : task
                case .failure(let error):
                    if scheduled { self.countdown?.failed = true }
                    self.report(error)
                    // A failed enable must not leave a previously enabled legacy
                    // setting unprotected. No administrator prompt in this path.
                    if target, latest == true {
                        do {
                            self.disabled = try watchdog.setDisabled(false, deadline: nil, policy: policy)
                            self.ownsSession = false
                        } catch { self.report(error) }
                    }
                }
                self.synchronizeCountdown()
                self.persistCountdown()
                self.updateDisplay()
                self.onChange?()
                self.tick()
            }
        }
    }

    private func confirmAuthorization() -> Bool {
        if let authorizationConfirmation { return authorizationConfirmation() }
        let alert = NSAlert()
        let lang = AppLanguage.current
        alert.messageText = lang.text("允许免密切换睡眠设置？", "Allow password-free sleep controls?")
        alert.informativeText = lang.text(
            "将为本账户保存一条 sudoers 规则，仅允许两条 pmset disablesleep 命令。同一账户下的其他进程也能使用它；删除应用不会移除规则。安全监控会作为后台项目运行。可在选项中移除授权。",
            "This saves a sudoers rule for exactly two pmset disablesleep commands. Other processes running as your account can use it too, and deleting the app leaves the rule installed. A safety watchdog runs as a background item. You can remove authorization in Options & safety.")
        alert.addButton(withTitle: lang.text("继续", "Continue"))
        alert.addButton(withTitle: lang.text("取消", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func maintainSession() {
        guard ownsSession else { return }
        do {
            if disabled == false {
                if let stop = try watchdog.lastStop() {
                    handleStop(stop)
                    return
                }
                _ = try watchdog.setDisabled(false, deadline: nil, policy: policy)
                ownsSession = false
            } else if let reason = try watchdog.heartbeat(deadline: safetyDeadline, policy: policy) {
                handleStop(reason)
            }
        } catch {
            report(error)
            // Failed lease I/O must not keep a persistent setting unprotected.
            do {
                _ = try control.setDisabled(false)
                handleStop(.watchdogUnavailable)
            } catch { report(error) }
        }
    }

    private func handleStop(_ reason: SafetyStop) {
        ownsSession = false
        disabled = try? control.readState()
        countdown = nil
        remaining = ""
        persistCountdown()
        message = reason.localizedDescription
        updateDisplay()
        onChange?()
    }

    func saveSettings() {
        guard !demo else { return }
        defaults.set(keepDisplayAwake, forKey: "LidOff.keepDisplayAwake")
        defaults.set(onlyOnAC, forKey: "LidOff.onlyOnAC")
        defaults.set(batteryThreshold, forKey: "LidOff.batteryThreshold")
        defaults.set(preventIdleLock, forKey: "LidOff.preventIdleLock")
        defaults.set(stopInLowPowerMode, forKey: "LidOff.stopInLowPowerMode")
        maintainSession()
        updateDisplay()
    }

    func setShortcutEnabled(_ enabled: Bool) {
        do {
            if !demo { try onShortcutPreferenceChanged?(enabled) }
            shortcutEnabled = enabled
            if !demo { defaults.set(enabled, forKey: "LidOff.shortcutEnabled") }
        } catch { report(error) }
    }

    func setNotifyBeforeEnd(_ enabled: Bool) {
        if demo { notifyBeforeEnd = enabled; return }
        if !enabled {
            notifyBeforeEnd = false
            defaults.set(false, forKey: "LidOff.notifyBeforeEnd")
            SessionNotifications.synchronize(task: countdown, enabled: false)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { allowed, error in
            DispatchQueue.main.async {
                self.notifyBeforeEnd = allowed
                self.defaults.set(allowed, forKey: "LidOff.notifyBeforeEnd")
                if let error { self.report(error) }
                else if !allowed { self.message = AppLanguage.current.text("请在系统设置中允许通知。", "Allow notifications in System Settings.") }
                SessionNotifications.synchronize(task: self.countdown, enabled: allowed)
            }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !demo else { launchAtLogin = enabled; return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin {
                message = AppLanguage.current.text("请在系统设置的登录项中允许此应用。", "Allow this app in System Settings → General → Login Items.")
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { report(error) }
    }

    func repairAuthorization() {
        guard !busy, !demo, confirmAuthorization() else { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [authorization] in
            let result = Result { try authorization.configure(enable: true); try authorization.verifyAccess() }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success: self.message = nil
                case .failure(let error): self.report(error)
                }
                self.refresh()
            }
        }
    }

    func removeAuthorizationAndQuit() {
        guard !busy else { return }
        if demo { return }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [watchdog, authorization] in
            let result = Result {
                // The administrator removal script restores sleep first, even
                // when the passwordless rule is broken or already missing.
                try authorization.configure(enable: false)
                _ = try watchdog.setDisabled(false, deadline: nil, policy: SafetyPolicy())
                if SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
                try watchdog.uninstall()
            }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success:
                    self.ownsSession = false
                    self.disabled = false
                    self.countdown = nil
                    self.persistCountdown()
                    self.updateDisplay()
                    NSApp.terminate(nil)
                case .failure(let error): self.refresh(); self.report(error)
                }
            }
        }
    }

    func prepareToQuit() -> Bool {
        guard !busy else { return false }
        if demo { return true }
        do {
            let actual = try control.readState()
            if ownsSession || actual {
                _ = try watchdog.setDisabled(false, deadline: nil, policy: policy)
            }
            disabled = false
            ownsSession = false
            synchronizeCountdown()
            updateDisplay()
            return true
        } catch { report(error); return false }
    }

    private func updateDisplay() {
        guard !demo else { return }
        let active = disabled == true && ownsSession
        do { try display.update(keepAwake: active && (keepDisplayAwake || preventIdleLock), preventIdleLock: active && preventIdleLock) }
        catch { report(error) }
    }

    private func synchronizeCountdown() {
        guard var task = countdown, !task.failed, let disabled else { return }
        let previous = task
        if disabled { task.resume(at: Date()) } else { task.pause(at: Date()) }
        guard task != previous else { return }
        countdown = task
        persistCountdown()
    }

    private func report(_ error: Error) {
        if case SleepControlError.cancelled = error { return }
        message = error.localizedDescription
    }

    private func persistCountdown() {
        guard !demo else { return }
        SessionNotifications.synchronize(task: countdown, enabled: notifyBeforeEnd)
        if let countdown, let data = try? JSONEncoder().encode(countdown) {
            defaults.set(data, forKey: storageKey)
        } else { defaults.removeObject(forKey: storageKey) }
    }

    private func tick() {
        if !demo, !busy, ProcessInfo.processInfo.systemUptime - lastPoll >= 5 {
            lastPoll = ProcessInfo.processInfo.systemUptime
            refresh()
        }
        guard let task = countdown else { remaining = ""; return }
        remaining = task.remainingText(at: Date())
        if task.isDue(at: Date()), !busy { execute(task.disableSleep, scheduled: true) }
    }
}

struct SleepPanel: View {
    @ObservedObject var model: SleepModel
    @AppStorage("LidOff.language") private var language = AppLanguage.systemDefault.rawValue
    @State private var minutes = "30"
    @State private var target = false
    @State private var settingsExpanded = false

    init(model: SleepModel, minutes: String = "30", target: Bool = false, settingsExpanded: Bool = false) {
        self.model = model
        self._minutes = State(initialValue: minutes)
        self._target = State(initialValue: target)
        self._settingsExpanded = State(initialValue: settingsExpanded)
    }

    private var lang: AppLanguage { AppLanguage(rawValue: language) ?? .systemDefault }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LidOff").font(.system(size: 14, weight: .semibold))
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
                    Toggle("LidOff", isOn: Binding(get: { model.disabled ?? false }, set: { model.toggle($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(model.disabled == nil)
                        .accessibilityLabel("LidOff")
                }
            }
            Divider()
            if let task = model.countdown {
                HStack(spacing: 8) {
                    Image(systemName: task.isPaused ? "pause.circle" : "timer")
                        .foregroundStyle(.secondary)
                        .help(task.isPaused ? lang.text("已暂停", "Paused") : lang.text("倒计时", "Countdown"))
                    Text(task.failed ? lang.text("执行失败", "Failed") : model.remaining)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Text(task.disableSleep ? lang.text("禁止睡眠", "Keep awake") : lang.text("恢复睡眠", "Until sleep allowed"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if task.isPaused {
                        Text(lang.text("（已暂停）", "(Paused)"))
                            .font(.system(size: 10, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Spacer(minLength: 0)
                    if task.failed {
                        Button(action: model.retryCountdown) { Image(systemName: "arrow.clockwise") }
                            .help(lang.text("重试", "Retry"))
                            .disabled(task.isPaused)
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
            DisclosureGroup(lang.text("选项与安全", "Options & safety"), isExpanded: $settingsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(lang.text("保持屏幕常亮", "Keep display awake"), isOn: $model.keepDisplayAwake)
                        .onChange(of: model.keepDisplayAwake) { _ in model.saveSettings() }
                    Toggle(lang.text("防止闲置锁屏（实验性）", "Prevent idle lock (experimental)"), isOn: $model.preventIdleLock)
                        .onChange(of: model.preventIdleLock) { _ in model.saveSettings() }
                    Text(lang.text("会话期间保持显示，并定期报告活动；不改系统设置，不能解锁或覆盖管理策略。", "Keeps the display awake and renews activity during a session. No settings changes; cannot unlock or override managed policy."))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Toggle(lang.text("仅连接电源时运行", "Only while on AC power"), isOn: $model.onlyOnAC)
                        .onChange(of: model.onlyOnAC) { _ in model.saveSettings() }
                    Toggle(lang.text("电池低电量模式时停止", "Stop in Low Power Mode on battery"), isOn: $model.stopInLowPowerMode)
                        .onChange(of: model.stopInLowPowerMode) { _ in model.saveSettings() }
                    Picker(lang.text("低电量停止", "Stop on low battery"), selection: $model.batteryThreshold) {
                        ForEach([10, 15, 20, 25, 30, 40, 50], id: \.self) { Text("\($0)%").tag($0) }
                    }.onChange(of: model.batteryThreshold) { _ in model.saveSettings() }
                    Text(lang.text("默认在电量 ≤20% 或温度过高时恢复睡眠。退出应用也会恢复睡眠。", "Stops at the battery limit or high thermal pressure. Quitting also restores sleep."))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Toggle(lang.text("全局快捷键 ⌥⌘S", "Global shortcut ⌥⌘S"), isOn: Binding(get: { model.shortcutEnabled }, set: model.setShortcutEnabled))
                    Toggle(lang.text("结束前 1 分钟通知", "Notify one minute before ending"), isOn: Binding(get: { model.notifyBeforeEnd }, set: model.setNotifyBeforeEnd))
                    Toggle(lang.text("登录时启动", "Launch at login"), isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                    Button(lang.text("修复免密授权…", "Repair authorization…"), action: model.repairAuthorization)
                    Button(lang.text("移除授权并退出…", "Remove authorization and quit…"), action: model.removeAuthorizationAndQuit)
                    Button(lang.text("退出（恢复睡眠）", "Quit (restore sleep)")) { NSApp.terminate(nil) }
                }
                .font(.system(size: 11))
                .padding(.top, 8)
                .disabled(model.busy)
            }.font(.system(size: 11))
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
    private var notificationPrefix: String { Bundle.main.bundleIdentifier ?? "local.lidoff.app" }
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var forwardingOnly = false
    private lazy var hotKey = GlobalHotKey { [weak self] in
        guard let self, let disabled = self.model.disabled else { return }
        self.model.toggle(!disabled)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.lidoff.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            forwardingOnly = true
            if let command = try? AutomationCommand.parse(Array(CommandLine.arguments.dropFirst())) {
                DistributedNotificationCenter.default().postNotificationName(.init(notificationPrefix + ".command"), object: nil, userInfo: command.userInfo, deliverImmediately: true)
                NSApp.terminate(nil)
                return
            }
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
        let positionKey = "NSStatusItem Preferred Position LidOff"
        let placementKey = "LidOff.rightSidePlacement.v1"
        if !defaults.bool(forKey: placementKey) || defaults.object(forKey: positionKey) == nil {
            defaults.set(0, forKey: positionKey)
            defaults.set(true, forKey: placementKey)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "LidOff"
        statusItem.isVisible = true
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: SleepPanel(model: model))
        model.onChange = { [weak self] in self?.updateIcon() }
        model.onShortcutPreferenceChanged = { [weak self] enabled in try self?.hotKey.setEnabled(enabled) }
        do { try hotKey.setEnabled(model.shortcutEnabled) } catch { model.message = error.localizedDescription }
        model.activate()
        if let command = try? AutomationCommand.parse(Array(CommandLine.arguments.dropFirst())) {
            Task { @MainActor in
                while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
                model.apply(command)
            }
        }

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(handleCommand(_:)), name: .init(notificationPrefix + ".command"), object: nil)
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
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LidOff")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = model.disabled == true ? "LidOff: On" : model.disabled == false ? "LidOff: Off" : "LidOff"
        statusItem.button?.setAccessibilityLabel(statusItem.button?.toolTip)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if forwardingOnly || model.prepareToQuit() { return .terminateNow }
        showPopover()
        return .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    @objc private func handleCommand(_ notification: Notification) {
        guard let command = AutomationCommand(userInfo: notification.userInfo) else { return }
        model.refresh()
        model.apply(command)
        if model.message != nil { showPopover() }
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
struct LidOffApp {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] { print(AutomationCommand.usage); return }
        if arguments == ["--status"] {
            do { print(try SleepControl().readState() ? "on" : "off") }
            catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        do { _ = try AutomationCommand.parse(arguments) }
        catch { fputs(AutomationCommand.usage + "\n", stderr); exit(2) }
        LegacyMigration.importPreferences()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

#endif
