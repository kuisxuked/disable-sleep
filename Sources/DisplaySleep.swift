import Foundation
import IOKit.pwr_mgt

protocol DisplayAssertions {
    func createDisplay() throws -> IOPMAssertionID
    func declareActivity(reusing id: IOPMAssertionID) throws -> IOPMAssertionID
    func release(_ id: IOPMAssertionID)
}

struct SystemDisplayAssertions: DisplayAssertions {
    func createDisplay() throws -> IOPMAssertionID {
        var id = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "LidOff active session" as CFString, &id)
        guard result == kIOReturnSuccess else { throw failure() }
        return id
    }

    func declareActivity(reusing id: IOPMAssertionID) throws -> IOPMAssertionID {
        var current = id
        let result = IOPMAssertionDeclareUserActivity("LidOff idle-lock prevention" as CFString, kIOPMUserActiveLocal, &current)
        guard result == kIOReturnSuccess else { throw failure() }
        return current
    }

    func release(_ id: IOPMAssertionID) { IOPMAssertionRelease(id) }

    private func failure() -> SleepControlError {
        .commandFailed(AppLanguage.current.text("无法保持屏幕或用户活动。", "Could not maintain display or user activity."))
    }
}

/// Process-owned assertions only: no display, screensaver or password preferences
/// are written. Activity renewal is best effort, not an unlock or an MDM override.
@MainActor
final class DisplaySleep {
    private let api: any DisplayAssertions
    private var assertion: IOPMAssertionID?
    private var activity: IOPMAssertionID?
    private var lastActivity: TimeInterval?

    init(api: any DisplayAssertions = SystemDisplayAssertions()) { self.api = api }

    // The model refreshes every five seconds. Use monotonic time so wall-clock
    // changes cannot suppress renewals. Keep the returned ID for the next call.
    func update(keepAwake: Bool, preventIdleLock: Bool = false,
                uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws {
        if !preventIdleLock {
            if let activity { api.release(activity); self.activity = nil }
            lastActivity = nil
        }
        if keepAwake || preventIdleLock {
            if assertion == nil { assertion = try api.createDisplay() }
        } else if let assertion {
            api.release(assertion)
            self.assertion = nil
        }
        if preventIdleLock, lastActivity.map({ uptime - $0 >= 15 || uptime < $0 }) ?? true {
            activity = try api.declareActivity(reusing: activity ?? IOPMAssertionID(kIOPMNullAssertionID))
            lastActivity = uptime
        }
    }

    deinit {
        if let activity { api.release(activity) }
        if let assertion { api.release(assertion) }
    }
}
