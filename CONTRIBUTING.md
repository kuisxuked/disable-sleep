# Contributing

Use macOS 13+ and Apple's Command Line Tools. Open `Package.swift` in Xcode for source navigation; `swift build` checks the app executable. `./build.sh` assembles the runnable app, including its separate watchdog, Info.plist, and icon. For full app behavior, build the bundle and attach Xcode's debugger to its `LidOff` process. The bare Swift package executable lacks a bundle identity and bundled helper and cannot start protected sessions.

Run `./test.sh` before submitting a pull request. It reads live power state but never writes real power settings, installs a sudoers rule, registers a background agent, or changes login items. Safety and failure tests use fake command runners and temporary state directories. Run `ARCHS='arm64 x86_64' ./build.sh` for the universal build. Do not use a real power write as an automated test.

For UI review use `./scripts/render-demo.sh` and the resulting `.build/RenderDemo`, which uses an isolated demo model. Keep English and Chinese labels and both READMEs consistent. Explain behavior changes and meaningful verification in the PR. Avoid unrelated formatting changes.

Hardware checks (manual, with explicit consent on the test Mac): test deadline expiry, app force-quit, watchdog disablement, battery/AC transitions, display timeout and lock behavior, normal quit, revocation, login/logout, Intel and Apple Silicon. Confirm that restoration means “allow normal sleep,” not “force sleep immediately.” Do not induce unsafe temperatures to test thermal handling; use injected snapshots.

For releases, bump `Resources/Info.plist`, update `CHANGELOG.md` and `RELEASE_NOTES.md`, then run `./release.sh`. This runs tests, builds both architectures, verifies signatures, creates versioned and stable-name ZIPs, checksums, and a checksum-pinned Homebrew cask. Tagging `v<version>` runs the release workflow, which generates provenance and prepares a draft release. Review and publish it manually. A local build alone does not publish or create an attestation.

Developer ID signing and notarization are optional release inputs; see `docs/DISTRIBUTION.md`. Do not commit certificates, passwords, API keys or credentials. See [SECURITY.md](SECURITY.md) for vulnerability reports.
