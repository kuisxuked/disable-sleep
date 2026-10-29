import Foundation
import IOKit.ps

struct PowerSnapshot: Sendable {
    let onAC: Bool?
    let batteryPercent: Int?
    let hasBattery: Bool
    let thermalState: ProcessInfo.ThermalState
    var lowPowerMode = false

    static func read() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerSnapshot(onAC: nil, batteryPercent: nil, hasBattery: true, thermalState: ProcessInfo.processInfo.thermalState, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        let supply = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        var percent: Int?
        var hasBattery = false
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            hasBattery = true
            if let current = description[kIOPSCurrentCapacityKey] as? Int,
               let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 {
                percent = min(100, max(0, current * 100 / maximum))
            }
        }
        return PowerSnapshot(onAC: supply.map { $0 == kIOPSACPowerValue }, batteryPercent: percent,
                             hasBattery: hasBattery, thermalState: ProcessInfo.processInfo.thermalState, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}

enum SafetyStop: String, Codable, Error, LocalizedError {
    case deadline, appUnavailable, lowBattery, acRequired, thermal, powerUnknown, watchdogUnavailable, lowPowerMode

    var errorDescription: String? {
        let lang = AppLanguage.current
        switch self {
        case .deadline: return lang.text("倒计时结束，已恢复正常睡眠。", "Countdown ended. Normal sleep restored.")
        case .appUnavailable: return lang.text("应用停止响应，已恢复正常睡眠。", "The app stopped responding. Normal sleep restored.")
        case .lowBattery: return lang.text("电量达到保护阈值，已恢复正常睡眠。", "Battery reached the safety threshold. Normal sleep restored.")
        case .lowPowerMode: return lang.text("电池低电量模式已开启，已恢复正常睡眠。", "Low Power Mode is enabled on battery. Normal sleep restored.")
        case .acRequired: return lang.text("需要连接电源，已恢复正常睡眠。", "AC power is required. Normal sleep restored.")
        case .thermal: return lang.text("系统温度过高，已恢复正常睡眠。", "macOS reported high thermal pressure. Normal sleep restored.")
        case .powerUnknown: return lang.text("无法确认电源状态，已恢复正常睡眠。", "Power status could not be verified. Normal sleep restored.")
        case .watchdogUnavailable: return lang.text("安全监控未运行。请在系统设置中允许后台项目后重试。", "The safety watchdog is unavailable. Allow its background item in System Settings and retry.")
        }
    }
}

struct SafetyPolicy: Codable, Equatable, Sendable {
    var batteryThreshold = 20
    var onlyOnAC = false
    var stopInLowPowerMode = false

    enum CodingKeys: String, CodingKey { case batteryThreshold, onlyOnAC, stopInLowPowerMode }

    init(batteryThreshold: Int = 20, onlyOnAC: Bool = false, stopInLowPowerMode: Bool = false) {
        self.batteryThreshold = batteryThreshold
        self.onlyOnAC = onlyOnAC
        self.stopInLowPowerMode = stopInLowPowerMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        batteryThreshold = try values.decodeIfPresent(Int.self, forKey: .batteryThreshold) ?? 20
        onlyOnAC = try values.decodeIfPresent(Bool.self, forKey: .onlyOnAC) ?? false
        stopInLowPowerMode = try values.decodeIfPresent(Bool.self, forKey: .stopInLowPowerMode) ?? false
    }

    func stopReason(for snapshot: PowerSnapshot) -> SafetyStop? {
        if snapshot.thermalState == .serious || snapshot.thermalState == .critical { return .thermal }
        guard let onAC = snapshot.onAC else { return .powerUnknown }
        if onlyOnAC && !onAC { return .acRequired }
        if stopInLowPowerMode && !onAC && snapshot.lowPowerMode { return .lowPowerMode }
        if !onAC && snapshot.hasBattery {
            guard let percent = snapshot.batteryPercent else { return .powerUnknown }
            if percent <= max(5, min(95, batteryThreshold)) { return .lowBattery }
        }
        return nil
    }
}

struct SafetySession: Codable, Sendable {
    var heartbeat: Date
    var deadline: Date?
    var policy: SafetyPolicy

    func stopReason(at now: Date, snapshot: PowerSnapshot) -> SafetyStop? {
        if let deadline, now >= deadline { return .deadline }
        // A clock rollback also invalidates the lease instead of extending it.
        if now.timeIntervalSince(heartbeat) >= 45 || heartbeat.timeIntervalSince(now) > 5 { return .appUnavailable }
        return policy.stopReason(for: snapshot)
    }
}

struct SafetyRecord: Codable, Sendable {
    var session: SafetySession?
    var lastCheck: Date?
    var lastStop: SafetyStop?
}
