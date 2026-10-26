## Disable Sleep 1.4.1 — countdowns pause with the main switch

- Turning **Disable Sleep off** now pauses the countdown and freezes its remaining time.
- Turning it **on again** resumes from the remaining time instead of the old deadline.
- The panel shows **Paused / 已暂停** with a small pause icon.
- Paused state and remaining time survive app restarts. Existing v1.4.0 timers migrate automatically.
- New timers created while Disable Sleep is off start paused. Never mode still removes the timer and keeps sleep disabled.

**Download:** `DisableSleep-1.4.1-macOS-universal.zip` — macOS 13+, Apple Silicon and Intel. SHA-256 checksums are in `SHA256SUMS.txt`.

This community build is locally signed, not Apple-notarized. See the README for the macOS first-launch flow and one-time administrator authorization.

---

关闭 Disable Sleep 时，倒计时会暂停；重新开启后从剩余时间继续。面板显示「已暂停」，重启应用也会保留暂停状态。旧版本已有倒计时会自动迁移。
