<div align="center">
  <img src="docs/assets/icon.png" width="84" alt="LidOff app icon">
  <h1>LidOff</h1>
  <p><strong>Keep your Mac awake with the lid closed—from one tiny menu bar switch.</strong></p>
  <p>
    <a href="https://github.com/kuisxuked/lidoff/releases/latest"><img alt="Download latest release" src="https://img.shields.io/github/v/release/kuisxuked/lidoff?style=flat-square&color=ed9f35&label=download"></a>
    <a href="https://github.com/kuisxuked/lidoff/actions/workflows/check.yml"><img alt="Build and test" src="https://github.com/kuisxuked/lidoff/actions/workflows/check.yml/badge.svg"></a>
    <img alt="macOS 13 or newer" src="https://img.shields.io/badge/macOS-13%2B-242938?style=flat-square">
    <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Universal-Apple%20Silicon%20%2B%20Intel-242938?style=flat-square">
    <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-242938?style=flat-square"></a>
  </p>
  <p><a href="https://kuisxuked.github.io/lidoff/">Project page</a> · <a href="https://github.com/kuisxuked/lidoff/releases/latest">Download for Mac</a> · <a href="README.zh-CN.md">简体中文</a></p>
  <img src="docs/assets/demo.gif" width="760" alt="Native interface walkthrough: switch language, keep awake, select Never, start and cancel a countdown">
  <p><sub>Native UI walkthrough, recorded from the actual app in isolated demo mode. No power settings are changed by the demo.</sub></p>
</div>

> **Development preview · 1.5.0 is unreleased.** This README describes the upcoming LidOff build. Older releases may still use the previous name and do not include the new safety, display, or idle-lock controls. Build this checkout to try them; use the Releases page to inspect the version you download.

## A little switch for a familiar problem

Running a download, a long task, or your own workflow with the lid closed should take one click. LidOff wraps the same `pmset` setting you would otherwise type in Terminal, with a compact native interface.

| You need | You get |
| --- | --- |
| Keep the Mac awake | One menu bar switch, with the real system state |
| Return to normal sleep later | A countdown backed by an independent safety watchdog |
| Keep the screen on during idle time | Optional **Keep display awake**, without changing saved timeouts |
| Protect battery and cooling | Battery threshold, optional AC-only mode, and thermal guard |
| Keep going without a timer | **Never**—battery, thermal, crash and quit protection still apply |
| Switch languages | A tiny **中 / EN** button; no extra panel |
| Avoid the camera notch | An initial slot on the right; Command-drag to reposition |
| Stop retyping a password | One-time authorization for two exact power commands |

## Why LidOff?

LidOff uses `pmset disablesleep` for closed-lid work, rather than only holding a normal idle-sleep assertion. [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) wraps `caffeinate` and explicitly documents that a closed lid is outside its scope. Closed-lid behavior still needs checking on your Mac model and macOS version.

Use LidOff for downloads, uploads, builds, renders, or a remote session you want to keep reachable. Start with a timer and the default 20% battery cutoff; keep the Mac on a ventilated surface.

## Quick Start

**When 1.5.0 is published:** [download the Universal ZIP](https://github.com/kuisxuked/lidoff/releases/latest), unzip it, and open **LidOff.app**. It works on Apple Silicon and Intel Macs running macOS 13 or later.

After that release is published, these **three commands** use its stable download asset:

```sh
curl -fL https://github.com/kuisxuked/lidoff/releases/latest/download/LidOff-macOS-universal.zip -o LidOff.zip
ditto -x -k LidOff.zip .
open "LidOff.app"
```

Click the sun or moon in your menu bar. Read the first-use authorization explanation and approve the administrator prompt once; later switches are password-free. Move the app to Applications before enabling **Options & safety → Launch at login**. Allow its background safety item in System Settings if macOS requests it. These controls and the stable-name download asset are new in v1.5.0.

> **First launch:** this community build is locally signed, **not Apple-notarized**. macOS may block an internet download. If you trust this source, use **System Settings → Privacy & Security → Open Anyway**. [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac). No security settings need to be globally disabled.

## How it works

- **Switch on:** `pmset -a disablesleep 1` — prohibit system sleep.
- **Switch off:** `pmset -a disablesleep 0` — allow normal sleep again.
- **Countdown:** enter a minute count or pick a preset, choose **Keep awake** or **Allow sleep**, then **Start**. One timer runs at a time. Turning the main switch off pauses it; turning the switch on resumes the remaining time. A timer created while the switch is off stays paused.
- **Never:** pick **Never** in the time field and press **Start**. This cancels the timer and keeps sleep disabled while the app is healthy and safety conditions permit.
- **中 / EN:** tap the tiny button beside the app name. Your language choice is saved.

The setting applies on battery and AC power and disables **idle system sleep**. **Quitting now restores normal sleep.** Allowing sleep does not force immediate sleep, and other apps or normal macOS closed-display conditions may still keep the Mac awake. Keep the Mac ventilated when running with its lid closed.

**Options & safety** contains:

- **Keep display awake:** a temporary IOKit assertion prevents automatic idle display sleep during a keep-awake session. Your saved display timeout is unchanged. The assertion ends when the session or app ends. It does not bypass screen locking, keep a physically closed built-in display lit, or guarantee an external display stays lit under every dock/monitor configuration. [Apple's display assertion documentation](https://developer.apple.com/documentation/iokit/1557127-iopmassertiondeclareuseractivity).
- **Prevent idle lock (experimental):** an opt-in control holds the display awake and renews local user activity every 15 seconds while the app owns a keep-awake session. It writes no macOS display, screen-saver, password, or lock preferences and requires no Accessibility permission. Activity stops when the option or session ends, or the process exits. This is best effort: it cannot unlock a Mac or override managed lock policy, and needs an actual idle-duration check on your macOS version before relying on it.
- **Battery protection:** default stop at **20% or below while on battery**, with selectable thresholds. **Only while on AC power** and **Stop in Low Power Mode on battery** are optional. The Low Power Mode guard does not stop sessions on AC power. Missing power information fails closed. Serious or critical macOS thermal pressure always ends a session; no unsafe temperature testing is needed.
- **Global shortcut ⌥⌘S:** optional system-wide toggle, with conflict reporting; no Accessibility permission required.
- **Notify one minute before ending:** optional local countdown warning, subject to macOS notification permission and Focus settings.
- **Launch at login**, **Repair authorization**, **Remove authorization and quit**, and **Quit (restore sleep)**.

A separate, unprivileged LaunchAgent checks the persisted safety lease every 10 seconds, including after an app crash. It restores sleep at the deadline, on battery/AC/thermal guard conditions, or after 45 seconds without a healthy app heartbeat (normally on the next check, about 45–55 seconds after a crash). It never enables sleep prevention. The app refuses new sessions without recent proof that the watchdog ran, and restores sleep if the helper stops checking. Failed restores remain pending for retry. **Never** removes the countdown, not these protections.

Countdown pause/resume state survives restarts. Failed tasks stay available for Retry. An active session ends on normal quit, crash recovery or a safety stop; restart does not silently recreate it. A sleeping Mac cannot run the app or watchdog: checks resume on wake. The LaunchAgent runs only while logged in and reconciles at next login after logout. Removing sudo permission or disabling background execution can prevent recovery. See [SECURITY.md](SECURITY.md) for these limits.

## Automation

The bundled executable supports commands suitable for a Shortcuts **Run Shell Script** action:

```sh
"/Applications/LidOff.app/Contents/MacOS/LidOff" --on --minutes 30
"/Applications/LidOff.app/Contents/MacOS/LidOff" --off
"/Applications/LidOff.app/Contents/MacOS/LidOff" --status
```

`--toggle`, `--on` (no countdown), `--show`, `--quit` and `--help` are also available. Actions are passed to the running app and use the same authorization and safety controls. `--status` only reads the setting. A successful command handoff is not confirmation of an asynchronous power change; use `--status` or inspect the panel. Commands received while busy report that they need retrying.

<details>
<summary><strong>What does the one-time authorization permit?</strong></summary>

Setup adds one root-owned `0440` file at `/private/etc/sudoers.d/lidoff-<your UID>`. It grants your account exactly these two commands:

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

No shell, unrestricted `sudo`, or other `pmset` arguments are allowed by this rule. Other processes running as your account can also execute these two commands. The app does not store passwords, run a privileged background service, collect analytics, or send power settings to a server. The watchdog runs as your user. The first-use dialog explains this boundary before the administrator prompt.

The installer validates the existing configuration and the new rule with `visudo`, refuses unexpected files, and installs atomically. It requires the standard macOS `sudoers.d` include and leaves the main sudoers file unchanged. Switching uses `sudo -n -k`: no interactive password prompts and no reliance on cached credentials. Starting a session also checks effective authorization for both exact commands with `sudo -l`. **Repair authorization** can reinstall the marked rule if it has been changed.

</details>

## Build it yourself

Install Apple's Command Line Tools (`xcode-select --install`), then:

```sh
git clone https://github.com/kuisxuked/lidoff.git && cd lidoff
./build.sh && ./test.sh
open "LidOff.app"
```

No third-party app dependencies. Open `Package.swift` in Xcode for source navigation and debugging; `./build.sh` assembles the full app and watchdog. `./release.sh` runs tests first, builds both architectures with hardened runtime, creates Universal ZIPs, generates a checksum-pinned Homebrew cask, and writes `dist/SHA256SUMS.txt`. Check a downloaded release with `shasum -a 256 -c SHA256SUMS.txt` in the download folder.

Tests cover power-state parsing (including fresh Macs), exact command arguments, setup cancellation, authorization errors, state verification, sudoers syntax, countdown boundaries, persistence, and wake catch-up. They do not install permissions or change power settings. The Universal build is cross-compiled for both architectures; physical lid-close behavior depends on your hardware and is a manual check.

## Distribution

The tag-triggered release workflow builds and attests the ZIPs and prepares a draft release. Developer ID signing and notarization are supported when the maintainer supplies the required identity and credentials. Default community builds remain ad-hoc signed and unnotarized. Sparkle and a signed, client-verifying privileged helper remain future work. See [distribution instructions](docs/DISTRIBUTION.md).

The generated `dist/lidoff.rb` is ready for a maintainer-owned Homebrew tap after its corresponding release is published. It is not an official Homebrew cask or an already-published tap. No external submissions or releases happen during a local build.

## Upgrading from the previous name

Quit the previous app before opening LidOff. LidOff imports its language, countdown, and other preferences once, without overwriting existing LidOff choices. The next authorization setup replaces the marked legacy sudoers rule, and starting a session restores normal sleep before retiring the old watchdog. A failed cleanup aborts the new session so competing watchdogs cannot silently run together. Remove the old app and its Login Item in System Settings after upgrading; enable LidOff’s own login item if wanted. New permission prompts can appear because LidOff has a new bundle identifier.

## Uninstall

Use **Options & safety → Remove authorization and quit**. Its administrator prompt restores sleep, removes the marked UID-specific sudoers file, unregisters the app login item and removes the watchdog. Then delete the app.

For manual recovery if the UI is unavailable:

```sh
sudo /usr/bin/pmset -a disablesleep 0
sudo rm -f "/private/etc/sudoers.d/lidoff-$(id -u)"
launchctl bootout "gui/$(id -u)/local.lidoff.watchdog"
rm -f "$HOME/Library/LaunchAgents/local.lidoff.watchdog.plist"
rm -rf "$HOME/Library/Application Support/LidOff"
```

Remove the app's Login Item in System Settings if necessary. Deleting the app alone leaves authorization and the copied watchdog behind; the watchdog attempts recovery when it next runs. Use the in-app removal control for complete cleanup.

## Share & contribute

Send a friend the [project page](https://kuisxuked.github.io/lidoff/) or the [latest download](https://github.com/kuisxuked/lidoff/releases/latest). Found a problem? [Open an issue](https://github.com/kuisxuked/lidoff/issues) with your macOS version, Mac model, and what happened. Please leave passwords and private logs out of issue reports. See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) and [SECURITY.md](SECURITY.md).

MIT licensed. Made by [kuisxuked](https://github.com/kuisxuked).
