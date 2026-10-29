# Changelog

This file follows Keep a Changelog, with version numbers following Semantic Versioning.

## [Unreleased] — 1.5.0

### Added

- Optional Low Power Mode stop on battery and experimental session-only idle-lock prevention with no macOS preference writes.
- One-time legacy preferences import and cleanup of the previous authorization/watchdog during upgrade.

- Independent unprivileged launchd watchdog with a persisted, locked recovery lease; deadline, heartbeat, battery, optional AC-only and thermal checks. Enabling requires a recently executing watchdog.
- Optional temporary display-wake assertion, global ⌥⌘S shortcut, one-minute local warning and launch-at-login toggle.
- Authorization explanation, effective permission verification, repair, removal and quit controls.
- Validated CLI for on/off/toggle, optional duration, status and UI handoff; usable from Shortcuts shell actions.
- Swift package for Xcode navigation, security/contribution docs, issue/PR templates, CI matrix, tag-triggered draft releases and build provenance, generated Homebrew cask, and optional Developer ID/notarization support.

### Changed

- Renamed the app, executables, bundle, CLI, distribution assets and documentation to LidOff.
- Project page explains development release status, practical use cases, and the closed-lid approach.

- Normal quit restores sleep. Never means no countdown; safety protections still apply. Sessions do not intentionally survive a stopped or unresponsive app.
- Child processes have bounded execution time; state reads retain the last known value on transient failure.
- Releases run tests first, enable hardened runtime, include a stable download asset, and hash the final archive and cask.

### Fixed

- Corrupt or forged countdown dates and paused durations could trap during floating-point-to-integer conversion and create a startup crash loop.
- Failed scheduled tasks could auto-pause and disable their Retry button; old saved failed/paused tasks are repaired.
- A forwarding secondary app instance must not restore the main app's session while exiting.

## [1.4.2]

### Changed

- English countdown label reads “Until sleep allowed”; compact paused marker uses a small serif italic style.

## [1.4.1]

### Added

- Countdown pause/resume tied to the main switch, with paused state persisted across restarts.
