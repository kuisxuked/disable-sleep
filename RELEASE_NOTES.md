## LidOff 1.5.0 (unreleased)

The app is renamed to **LidOff**, including its bundle, executable, release archives, CLI, watchdog and authorization files. Existing preferences are imported once and legacy authorization/watchdog cleanup is included.

Added optional **Stop in Low Power Mode on battery** and **Prevent idle lock (experimental)**. The latter renews user activity only during a session without changing macOS preferences; real idle-duration validation remains required.

Safety sessions now have an independent user-level watchdog. It restores normal sleep after a deadline, a missing app heartbeat, low battery (20% default), optional AC-only policy or serious/critical macOS thermal pressure. Normal quit also restores sleep. Never removes only the timer; safety protections remain active. The watchdog checks every 10 seconds while logged in, resumes checks after wake and reconciles abandoned sessions at next login. It is not a hardware safety guarantee or a privileged security boundary.

**Options & safety** adds temporary display wake, global ⌥⌘S, optional one-minute warning, launch at login, authorization repair/removal and quit. A small CLI supports Shortcuts shell actions. Display wake preserves the user's saved timeout and does not bypass screen locking.

Fixed the corrupt-countdown startup crash and failed-task Retry getting disabled. Added bounded subprocess execution, last-known-state retention, injected failure/recovery tests, a Swift package, security/contribution docs, CI matrix and release provenance workflow. Release scripts now run tests, enable hardened runtime, generate a Homebrew cask and support Developer ID/notarization when configured.

Apple Silicon + Intel Universal build; macOS 13+. Default community builds remain ad-hoc signed and **not Apple-notarized**. The Homebrew cask and provenance workflow are prepared locally; no tap, release, attestation or notarization is published by this change.

---

应用已更名为 **LidOff**，包括应用包、可执行文件、CLI、监控、授权文件和分发产物，并提供旧偏好迁移及旧监控清理。新增可选「电池低电量模式时停止」及「防止闲置锁屏（实验性）」；后者仅在会话中报告用户活动，不修改系统偏好，实际闲置锁屏效果仍待验证。

新增独立用户级安全监控，默认在电量 ≤20%、严重／临界温度压力、倒计时到期或应用心跳中断时恢复正常睡眠；可选仅接电运行。正常退出也恢复睡眠。「永不」只取消倒计时，安全保护仍生效。监控每 10 秒检查，仅登录期间运行，睡着后需等唤醒，下次登录会处理遗留会话。

新增保持屏幕常亮、全局 ⌥⌘S、提前 1 分钟通知、登录时启动、授权说明／修复／移除及退出按钮；支持快捷指令调用的 CLI。屏幕常亮不改动系统超时、不绕过锁屏。修复损坏倒计时导致启动崩溃、失败任务无法重试的问题，并加强命令超时、读取失败处理、测试和发布流程。默认仍未公证；本次只准备本地构建与分发流程，未发布。
