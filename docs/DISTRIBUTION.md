# Distribution

## Current handoff status

LidOff 1.5.0 is a local development build. Its app, Universal archives, cask,
documentation and page assets are prepared under the new name. Publishing still
requires publishing the reviewed source and release assets. The GitHub repository
has been renamed to `kuisxuked/lidoff`, and the local origin now uses
`https://github.com/kuisxuked/lidoff.git`. The page's canonical and sharing URLs target
the new repository name; verify GitHub Pages after publishing the page changes. Historical
release archives retain their original filenames.

No tap is published. The generated cask becomes installable only after its exact
versioned archive is uploaded to the renamed repository. Apple notarization also
requires a Developer ID identity and notary credentials; neither is available in
the current build environment. Do not label the local ZIP as notarized or attested.

`./release.sh` runs tests before building the app and watchdog for Apple Silicon and Intel. It enables hardened runtime, verifies both signatures and architectures, creates versioned and stable-name ZIPs, and generates checksums and `dist/lidoff.rb` from the final archive. Default local signing remains ad-hoc; hardened runtime alone does not make a build notarized or establish a trusted developer identity.

## Developer ID and notarization

With a Developer ID Application identity already installed in your keychain and credentials saved with `notarytool store-credentials`, run:

```sh
CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARYTOOL_PROFILE='lidoff-notary' ./release.sh
```

The script timestamps both executables, submits the archive, waits for acceptance, staples and validates the ticket, then recreates the ZIP and checksums. This path needs an Apple Developer membership, your signing identity and configured keychain credentials. None are bundled with this repository. The default GitHub workflow builds an ad-hoc signed release; it does not claim notarization.

## GitHub provenance and releases

The tag-triggered workflow verifies that `v<version>` matches the Info.plist, runs the release script, attests the release ZIPs, and creates a draft release. It needs GitHub Actions attestation support and repository token permissions. After that workflow succeeds, verify a downloaded ZIP with:

```sh
gh attestation verify LidOff-macOS-universal.zip --repo kuisxuked/lidoff
shasum -a 256 -c SHA256SUMS.txt
```

An attestation links a binary to a workflow and source revision. It is separate from Apple signing and notarization. Older releases and locally built ZIPs do not acquire attestations retroactively. The release workflow retains a draft for maintainer review before publication.

## Homebrew

The release script generates a checksum-pinned cask (`dist/lidoff.rb`) suitable for a tap. It points to that version's GitHub release; publish those assets before using the cask. No official Homebrew cask or tap is claimed to exist.

To maintain a tap, create a `homebrew-<tap>` repository, put the generated file at `Casks/lidoff.rb`, and then use `brew install --cask <owner>/<tap>/lidoff`. Validate the cask with `brew style` and `brew audit --cask` in the tap. Before a user uninstalls with Homebrew, they should use the app's **Remove authorization and quit** control: this restores sleep and removes the UID-specific rule, watchdog and app login item. The cask does not run arbitrary root cleanup scripts or silently remove persistent authorization.

Sparkle, a signed client-verifying privileged helper, automatic app/display/Wi-Fi triggers, time-of-day scheduling and more translations remain future work. They need their own design and verification; third-party updater integration also needs an update-signing key and a hosted feed. No release credentials, tap repository, feed or public submissions are created by a local build.
