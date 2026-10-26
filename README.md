<div align="center">
  <img src="docs/assets/icon.png" width="84" alt="Disable Sleep app icon">
  <h1>Disable Sleep</h1>
  <p><strong>Keep your Mac awake with the lid closed—from one tiny menu bar switch.</strong></p>
  <p>
    <a href="https://github.com/kuisxuked/disable-sleep/releases/latest"><img alt="Download latest release" src="https://img.shields.io/github/v/release/kuisxuked/disable-sleep?style=flat-square&color=ed9f35&label=download"></a>
    <img alt="macOS 13 or newer" src="https://img.shields.io/badge/macOS-13%2B-242938?style=flat-square">
    <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Universal-Apple%20Silicon%20%2B%20Intel-242938?style=flat-square">
    <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-242938?style=flat-square"></a>
  </p>
  <p><a href="https://kuisxuked.github.io/disable-sleep/">Project page</a> · <a href="https://github.com/kuisxuked/disable-sleep/releases/latest">Download for Mac</a> · <a href="README.zh-CN.md">简体中文</a></p>
  <img src="docs/assets/demo.gif" width="760" alt="Native interface walkthrough: switch language, keep awake, select Never, start and cancel a countdown">
  <p><sub>Native UI walkthrough, recorded from the actual app in isolated demo mode. No power settings are changed by the demo.</sub></p>
</div>

## A little switch for a familiar problem

Running a download, a long task, or your own workflow with the lid closed should take one click. Disable Sleep wraps the same `pmset` setting you would otherwise type in Terminal, with a compact native interface.

| You need | You get |
| --- | --- |
| Keep the Mac awake | One menu bar switch, with the real system state |
| Return to normal sleep later | A countdown in minutes, with a cancel button |
| Keep going indefinitely | **Never**—no automatic return to sleep |
| Switch languages | A tiny **中 / EN** button; no extra panel |
| Avoid the camera notch | An initial slot on the right; Command-drag to reposition |
| Stop retyping a password | One-time authorization for two exact power commands |

## Quick Start

**Easiest:** [download the Universal ZIP](https://github.com/kuisxuked/disable-sleep/releases/latest), unzip it, and open **Disable Sleep.app**. It works on Apple Silicon and Intel Macs running macOS 13 or later.

Or run these **three commands**:

```sh
curl -fL https://github.com/kuisxuked/disable-sleep/releases/download/v1.4.0/DisableSleep-1.4.0-macOS-universal.zip -o DisableSleep.zip
ditto -x -k DisableSleep.zip .
open "Disable Sleep.app"
```

Click the sun or moon in your menu bar. Approve the administrator prompt once when you first switch; later switches are password-free. Move the app to Applications if you want, and add it in **System Settings → General → Login Items** to launch at login.

> **First launch:** this community build is locally signed, **not Apple-notarized**. macOS may block an internet download. If you trust this source, use **System Settings → Privacy & Security → Open Anyway**. [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). No security settings need to be globally disabled.

## How it works

- **Switch on:** `pmset -a disablesleep 1` — prohibit system sleep.
- **Switch off:** `pmset -a disablesleep 0` — allow normal sleep again.
- **Countdown:** enter a minute count or pick a preset, choose **Keep awake** or **Allow sleep**, then **Start**. One timer runs at a time.
- **Never:** pick **Never** in the time field and press **Start**. This cancels the timer and keeps sleep disabled until you turn the main switch off.
- **中 / EN:** tap the tiny button beside the app name. Your language choice is saved.

The setting applies on battery and AC power and also disables **idle system sleep**. It remains in effect when the app quits. Allowing sleep does not force immediate sleep, and other apps or normal macOS closed-display conditions may still keep the Mac awake. Keep the Mac ventilated when running with its lid closed.

Countdown deadlines survive app restarts. The app must be running to execute them; if the Mac is asleep or the app is closed when time runs out, the operation is applied after wake or the next launch. A timer does **not** wake a sleeping Mac. Failed timers stay visible for retry and do not repeatedly prompt.

<details>
<summary><strong>What does the one-time authorization permit?</strong></summary>

Setup adds one root-owned `0440` file at `/private/etc/sudoers.d/disablesleep-<your UID>`. It grants your account exactly these two commands:

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

No shell, unrestricted `sudo`, or other `pmset` arguments are allowed by this rule. Other processes running as your account can also execute these two commands. The app does not store passwords, run a privileged background service, collect analytics, or send power settings to a server.

The installer validates the existing configuration and the new rule with `visudo`, refuses unexpected files, and installs atomically. It requires the standard macOS `sudoers.d` include and leaves the main sudoers file unchanged. Switching uses `sudo -n -k`: no interactive password prompts and no reliance on cached credentials.

</details>

## Build it yourself

Install Apple's Command Line Tools (`xcode-select --install`), then:

```sh
git clone https://github.com/kuisxuked/disable-sleep.git && cd disable-sleep
./build.sh && ./test.sh
open "Disable Sleep.app"
```

No third-party app dependencies. `./release.sh` builds both architectures, creates a Universal ZIP, and writes `dist/SHA256SUMS.txt`. Check a downloaded release with `shasum -a 256 -c SHA256SUMS.txt` in the download folder.

Tests cover power-state parsing (including fresh Macs), exact command arguments, setup cancellation, authorization errors, state verification, sudoers syntax, countdown boundaries, persistence, and wake catch-up. They do not install permissions or change power settings. The Universal build is cross-compiled for both architectures; physical lid-close behavior depends on your hardware and is a manual check.

## Uninstall

Turn the main switch **off** if you want normal sleep restored. Quit with Activity Monitor, or from the app's folder:

```sh
open -n "Disable Sleep.app" --args --quit
sudo rm "/private/etc/sudoers.d/disablesleep-$(id -u)"
```

Then delete the app and remove its Login Item if you added one. Deleting the app alone does not restore sleep or revoke the saved authorization.

## Share & contribute

Send a friend the [project page](https://kuisxuked.github.io/disable-sleep/) or the [latest download](https://github.com/kuisxuked/disable-sleep/releases/latest). Found a problem? [Open an issue](https://github.com/kuisxuked/disable-sleep/issues) with your macOS version, Mac model, and what happened. Please leave passwords and private logs out of issue reports.

MIT licensed. Made by [kuisxuked](https://github.com/kuisxuked).
