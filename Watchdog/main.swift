import Foundation

// This executable has no AppKit lifecycle, UI, or administrator prompt.
do {
    try SafetyWatchdog().check()
} catch {
    fputs("LidOff watchdog: \(error.localizedDescription)\n", stderr)
    exit(1)
}
