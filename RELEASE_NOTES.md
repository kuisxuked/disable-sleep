## A tiny menu bar switch. A little less Terminal.

- Native macOS menu bar app with one-click sleep control.
- Tiny **中 / EN** language toggle; the panel stays compact.
- Editable countdown presets and a **Never / 永不** option for indefinite wakefulness.
- One-time authorization; subsequent switches do not request a password.
- Defaults to the right side of the menu bar, away from the camera notch.
- Saved countdowns resume after app relaunch; overdue timers catch up after wake.

### Download

**DisableSleep-1.4.0-macOS-universal.zip** supports Apple Silicon and Intel, macOS 13 or newer. Unzip and open **Disable Sleep.app**. The first actual change requests administrator authorization once.

This community build is locally signed, **not Apple-notarized**. If macOS blocks an internet download, follow Apple's Privacy & Security → Open Anyway flow only if you trust the source. Checksums are in **SHA256SUMS.txt**.

The switch controls `pmset -a disablesleep`, including idle sleep. Quitting does not reset it. Timers require the app to be running and do not wake a sleeping Mac. See the README for permissions and removal.

---

原生 macOS 菜单栏工具，支持小型中英文切换、倒计时与「永不」。首次授权一次，后续免密。通用版同时支持 Intel、Apple Silicon，最低 macOS 13。详见 [中文说明](https://github.com/kuisxuked/disable-sleep/blob/main/README.zh-CN.md)。
