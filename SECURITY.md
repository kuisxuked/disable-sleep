# Security policy

Please report suspected privilege escalation, command injection, or a tampered release privately through [GitHub's private vulnerability reporting](https://github.com/kuisxuked/lidoff/security/advisories/new). If private reporting is unavailable, open an issue requesting a private contact without publishing exploit details or personal logs. No response-time guarantee is offered.

The next release receives fixes; older releases should be upgraded. The current community builds use ad-hoc signatures and are not Apple-notarized. Checksums detect corruption; compare them through a trusted channel. New releases built by the release workflow also receive GitHub build-provenance attestations.

## Authorization boundary

An administrator authorizes a root-owned, mode `0440` sudoers file for a numeric UID. It grants only `/usr/bin/pmset -a disablesleep 0` and `/usr/bin/pmset -a disablesleep 1`. **Every process running under that UID can execute both commands.** This is persistent permission, not client-verified XPC. The in-app explanation discloses this before setup. Use **Options & safety → Remove authorization and quit** before deleting the app. The removal script restores sleep before removing the marked rule. It refuses unrelated files.

The app, helper, preference files, and watchdog files are user-writable. A malicious process under the same UID can replace them or stop the watchdog. The watchdog is an accident-recovery measure, not a security boundary against that user or against administrator/root access. Never approve an administrator prompt for an untrusted or modified copy.

## Watchdog limits

The unprivileged LaunchAgent checks every 10 seconds while the user is logged in. It uses the same exact sudo permission only to restore sleep. Recovery state is written atomically under a cross-process lock before sleep prevention is enabled. A missed app heartbeat expires after 45 seconds; the next available watchdog run restores sleep. Deadline, battery, AC and thermal checks apply even if the app crashes. Failed restoration remains pending for retry. The app also checks watchdog health and stops its session if the helper is no longer checking.

This is not a real-time or hardware safety guarantee. A sleeping Mac cannot execute checks; they resume on wake. A user LaunchAgent cannot run while logged out; abandoned sessions reconcile at the next login. Revoked sudo permission, disabled background execution, filesystem failure, or OS failure can prevent restoration. A future signed, client-verifying privileged helper is needed for a stronger authorization model and pre-login recovery. Keep the Mac ventilated; do not run it closed in a bag.

Display wake uses a temporary IOKit assertion. It ends with the session or process and does not disable screen locking or rewrite display timeouts.

## Display and idle-lock controls

Display wake and experimental idle-lock prevention use process-owned IOKit assertions. Idle-lock prevention renews local user activity every 15 seconds only while LidOff owns an active session. They do not write display, screen-saver, password, or lock preferences. Activity renewal is best effort; it cannot unlock an existing lock or override device-management policy. Manual locking remains available. Validate actual idle behavior on your macOS version before relying on this option.
