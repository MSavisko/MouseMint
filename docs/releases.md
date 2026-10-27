# Releases

MouseMint uses GitHub Actions, GitHub Releases, and Sparkle 2.10.1. Standard GitHub-hosted runners are free for this public repository. The `xcode-27` runner provides the project's exact Xcode 27.1 build; it is currently a preview image, so runner availability can change. No paid larger runner is used. CI preview artifacts expire after three days to limit storage.

The implementation is on the release-automation PR. Local tests, packaging and real Actions results are recorded below as they are verified. **A notarized release is not available yet:** the Developer ID certificate and Apple notarization credentials still need configuration.

## Normal release flow

1. Merge changes into `main` using conventional titles: `feat:` for features, `fix:` for fixes, `perf:` or `refactor:` for improvements. Release Please gathers these into a release PR with `CHANGELOG.md` and a version change in `version.txt`. Edit the generated notes in that PR before merging if needed.
2. Review and merge the release PR. Release Please creates a draft GitHub release. The same workflow calls the publisher directly, so GitHub's restriction on workflows triggered by `GITHUB_TOKEN` does not prevent publication.
3. The publisher verifies that the exact release commit belongs to `main`, rebuilds and tests it, signs the app and Sparkle's nested helpers with Developer ID, submits the app to Apple, and staples the accepted ticket.
4. It creates the DMG and ZIP from that stapled app, signs/notarizes/staples the DMG, signs the Sparkle update feed, uploads the files and checksums, then publishes the release. A failure leaves the release draft. Retrying is a manual workflow dispatch with that draft's tag and full commit SHA; published releases cannot be overwritten by this workflow.

Release Please-created PRs do not trigger normal `pull_request` workflows. The release workflow explicitly dispatches CI on their branch, using the short-lived `GITHUB_TOKEN`; no personal access token is required. Repository **Settings → Actions → General → Allow GitHub Actions to create and approve pull requests** must be enabled for PR creation. It is now enabled for MouseMint; default workflow token permissions remain read-only. The workflows do not approve or merge PRs.

The generated release PR is the review point. Routine releases need no manual packaging or release-note copying after the one-time credentials setup.

## Downloads and updates

| File | Purpose |
| --- | --- |
| `MouseMint-VERSION-arm64.dmg` | Mint installer window: drag MouseMint to Applications |
| `MouseMint-VERSION-arm64.zip` | Stapled app archive used by Sparkle; also available as a direct download |
| `appcast.xml` | Signed update metadata hosted on the latest GitHub release |
| `SHA256SUMS.txt` | Checksums of the installer, ZIP and feed |
| GitHub's source ZIP / tar.gz | Source snapshot for the release tag |

These builds support Apple Silicon and macOS 13 or later, matching the existing app. Intel distribution is not added by this pipeline.

Sparkle's standard UI handles checking, downloading and installing updates. Choose **Check for Updates…** from the menu or **Settings → About**. Sparkle manages automatic checks and update prompts. Release notes are embedded from the reviewed GitHub release body. The appcast URL is `https://github.com/MSavisko/MouseMint/releases/latest/download/appcast.xml`; download URLs point to the specific version's release assets.

`version.txt` is the version source. Tuist sets the marketing version from it and derives the build version as `(major + 100).minor.patch` (for example, `1.7.0` → `101.7.0`). This keeps Sparkle-enabled builds above the old integer build 8 and gives deterministic, increasing values. Minor/patch components must stay below 100 to meet Apple's documented bundle-version limits. Release tags must exactly match `vMAJOR.MINOR.PATCH` and `version.txt`.

`--read-json`, `--scroll-status` and `--check-ui --settings` never create or start Sparkle. Tests use fake updater backends and do not contact the feed or change update preferences. Preview installers from CI are ad-hoc signed and are **not** notarized releases; they are not published to the update feed.

## One-time Apple setup

An App Store login alone is insufficient. Direct distribution needs a paid Apple Developer Program membership, a **Developer ID Application** certificate with its private key, and notarization credentials. This pipeline distributes outside the Mac App Store; notarization is separate from App Store review.

In Xcode's account settings, create a Developer ID Application certificate for the intended team, or ask its Account Holder to create one. Apple requires the Account Holder role for an exportable Developer ID certificate; cloud-managed admin access is different. In Keychain Access, export that certificate **with its private key** as a password-protected `.p12`. An Apple Development or iPhone Distribution certificate cannot replace it. Do not commit the export.

Create an App Store Connect **team API key** that can use notarization, download its `.p8`, and note its key ID and issuer ID. Keep a secure backup; Apple allows downloading the private key only once. Never paste private keys or certificate passwords into PRs, issues or chat.

Configure the following encrypted secrets under **Repository Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | Base64 of the Developer ID Application `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that export |
| `APPLE_TEAM_ID` | Ten-character team ID matching the certificate |
| `APPLE_NOTARY_KEY` | Contents of the `.p8` team API private key |
| `APPLE_NOTARY_KEY_ID` | API key ID |
| `APPLE_NOTARY_ISSUER_ID` | API issuer UUID |
| `SPARKLE_PRIVATE_KEY` | Sparkle Ed25519 private signing key |

The Sparkle private key is configured in encrypted Actions secrets and retained in the Mac's login Keychain under account `io.github.msavisko.mousemint.sparkle`. `Resources/SparklePublicKey.txt` contains its **public verification key**; it is safe and necessary to ship with the app. Temporary exports are removed. Keep the private key private and preserve it across releases: existing installations trust its public counterpart.

The publisher creates an isolated temporary keychain on GitHub's disposable runner, imports only the Developer ID identity, and removes the keychain and credential files even after failure. Signing secrets are supplied only to the trusted publishing job, never PR CI. Do not enable shell tracing around credentials. Keep workflow changes reviewed; code running in the publisher can access these secrets.

## Local checks

```sh
mise install --locked
mise run generate
mise run release-check
mise run test
mise run build
mise exec -- python3 Tools/release.py package --tag "v$(cat version.txt)"
mise exec -- python3 Tools/verify-dmg.py "dist/release/MouseMint-$(cat version.txt)-arm64.dmg"
```

Packaging uses macOS's `hdiutil`, Finder, and a small AppKit background renderer. It needs a logged-in GUI session. It sets only the new disk image's Finder layout. There is no separate DMG-building dependency. The output is a development preview until the trusted publisher has completed Developer ID signing and notarization.

## Verification record

On 2026-10-27, the existing 56 native tests passed before changes. New updater contracts first failed against compiling stubs, then passed. New menu/About action tests first failed before wiring the controls, then passed. The full native suite now has 61 passing methods. Five Python release checks cover tag/version consistency, monotonic build versions, exact archive/feed metadata, missing credentials and the CI-only import guard. They failed behavior assertions before implementation. Actionlint checks workflow syntax; its runner-label extension records GitHub's new standard `xcode-27` label.

Local release generation and build passed with the locked Sparkle resolver. The DMG was mounted read-only and checked for the executable, deep signature, Applications shortcut, background and saved Finder layout. The background and updated About pane were visually inspected. The renderer also checks a fixed 680 × 420 pixel size to match Finder on both Retina and non-Retina hosts. A full Finder screenshot was not obtained: the computer-use connection was slow and only returned the desktop. This is not a claim of Apple notarization or a successful update installation.

A real, signed local Sparkle feed was generated with the approved Keychain key and passed exact archive/version/URL/signature-shape validation. The generated feed is kept under `.build` and has not been published. Generation in a clean path with spaces and metadata-only cache invalidation both passed. `Tools/project-environment.sh` supplies the version and public key as Tuist environment inputs so its manifest cache cannot reuse old metadata.

The final read-only native inspection passed in receiver mode (M3-A3, D031, firmware `1.2.3r`, 100%, on battery), with Check for Updates in the real menu. See [protocol evidence](usb-protocol.md#sparklerelease-wiring-check--2026-10-27). The first Actions run exposed omitted version/config inputs in the commit; these were added before retrying.

Real Actions success, notarization and update-installation results remain pending and must be recorded before calling the release setup complete.

## Sources

- [GitHub Actions free use and storage limits](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Standard hosted runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Installed Xcode 27 image software](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Release Please workflow and token behavior](https://github.com/googleapis/release-please-action)
- [Apple Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Sparkle setup and signing](https://sparkle-project.org/documentation/)
