# Releases

MouseMint uses GitHub Actions, GitHub Releases, and Sparkle 2.10.1. Standard GitHub-hosted runners are free for this public repository. The `xcode-27` runner provides the project's exact Xcode 27.1 build; it is currently a preview image, so runner availability can change. No paid larger runner is used. CI preview artifacts expire after three days to limit storage.

The pipeline was merged in [PR #1](https://github.com/MSavisko/MouseMint/pull/1). It generated [release PR #2 for 1.7.0](https://github.com/MSavisko/MouseMint/pull/2), including the version bump and release notes. **A notarized release is not available yet:** the Developer ID identity is installed on the Mac, but its CI certificate export and Apple notarization credentials still need configuration. The release PR remains unmerged.

## Normal release flow

1. Merge changes into `main` using conventional titles: `feat:` for features, `fix:` for fixes, `perf:` or `refactor:` for improvements. Release Please gathers these into a release PR with `CHANGELOG.md` and a version change in `version.txt`. Edit the generated notes in that PR before merging if needed.
2. Review and merge the release PR. Release Please creates a draft GitHub release. The same workflow calls the publisher directly, so GitHub's restriction on workflows triggered by `GITHUB_TOKEN` does not prevent publication.
3. The publisher verifies that the exact release commit belongs to `main`, rebuilds and tests it, signs the app and Sparkle's nested helpers with Developer ID, submits the app to Apple, and staples the accepted ticket.
4. It creates the DMG and ZIP from that stapled app, signs/notarizes/staples the DMG, signs the Sparkle update feed, uploads the files and checksums, then publishes the release. A failure leaves the release draft. Retrying is a manual workflow dispatch with that draft's tag and full commit SHA; published releases cannot be overwritten by this workflow.

The release workflow explicitly dispatches CI on the generated PR's branch, using the short-lived `GITHUB_TOKEN`; no personal access token is required. GitHub also creates a separate `pull_request` run that needs a repository writer's approval. Its **Approve workflows to run** banner can remain even after the dispatched CI passes. During release review, approve that run and wait for its result before merging; check that CI tested the PR's current commit. See [GitHub's token and approval rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

Repository **Settings → Actions → General → Allow GitHub Actions to create and approve pull requests** must be enabled for PR creation. It is enabled for MouseMint; default workflow token permissions remain read-only. The workflows do not approve or merge PRs.

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

If creating it on Apple's website, select **Developer ID Application** (the bottom option in the certificate list). When Apple asks for a certificate signing request:

1. Open Keychain Access on this Mac. Choose **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**.
2. Enter your email and a descriptive key name such as `MouseMint Developer ID`. Leave the certificate-authority email field blank.
3. Save the request to disk. Upload the resulting `.certSigningRequest` file on Apple's certificate page.
4. Download Apple's `.cer` file and open it on the same Mac. In Keychain Access, its certificate should expand to show the matching private key. Export that identity as the password-protected `.p12` needed by CI.

The CSR contains public information; the matching private key is created on your Mac. A `.cer` alone cannot sign the app. See [Apple's CSR instructions](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/).

Create an App Store Connect **team API key** with the **Developer** access role. A descriptive name such as `MouseMint Notarization` is enough. Download its `.p8` and note its key ID and issuer ID. Keep a secure backup; Apple allows downloading the private key only once. Never paste private keys or certificate passwords into PRs, issues or chat.

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

The Apple team ID is already configured in Actions from the installed Developer ID identity. The remaining Apple credentials are not configured yet.

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

On 2026-10-27, the existing 56 native tests passed before changes. New updater contracts first failed against compiling stubs, then passed. New menu/About action tests first failed before wiring the controls, then passed. The full native suite now has 61 passing methods. Six Python release checks cover tag/version consistency, monotonic build versions, exact archive/feed metadata, missing credentials, the CI-only import guard and suppression of credential arguments in process failures. They failed behavior assertions before implementation. Actionlint checks workflow syntax; its runner-label extension records GitHub's new standard `xcode-27` label.

Two additional Python tests exercise the real publishing shell with fake Apple/GitHub tools in disposable directories. The successful fixture uploads before publishing. Seven failure scenarios (app/DMG notarization, app/DMG stapling, feed signing, feed validation and upload) all leave the release unpublished. This brings the Python suite to eight methods and adds evidence for failure handling without accessing signing credentials or claiming real notarization.

Local release generation and build passed with the locked Sparkle resolver. The DMG was mounted read-only and checked for the executable, deep signature, Applications shortcut, background and saved Finder layout. The background and updated About pane were visually inspected. The renderer also checks a fixed 680 × 420 pixel size to match Finder on both Retina and non-Retina hosts. A full Finder screenshot was not obtained: the computer-use connection was slow and only returned the desktop. This is not a claim of Apple notarization or a successful update installation.

A real, signed local Sparkle feed was generated with the approved Keychain key and passed exact archive/version/URL/signature-shape validation. The generated feed is kept under `.build` and has not been published. Generation in a clean path with spaces and metadata-only cache invalidation both passed. `Tools/project-environment.sh` supplies the version and public key as Tuist environment inputs so its manifest cache cannot reuse old metadata.

The final read-only native inspection passed in receiver mode (M3-A3, D031, firmware `1.2.3r`, 100%, on battery), with Check for Updates in the real menu. See [protocol evidence](usb-protocol.md#sparklerelease-wiring-check--2026-10-27). The first Actions run exposed omitted version/config inputs in the commit; these were added before retrying.

[GitHub Actions run 40562095033](https://github.com/MSavisko/MouseMint/actions/runs/40562095033) passed locked installation, generation, resolver checks, release checks, real metadata-cache checks, all 61 native tests, release build, DMG creation/verification and preview upload. The preview is an ad-hoc development installer, not a notarized release.

[Release-management run 40564771368](https://github.com/MSavisko/MouseMint/actions/runs/40564771368) completed successfully after PR #1 merged. It actually created PR #2 with `version.txt`, the release manifest and changelog changed to `1.7.0`. A later update dispatched [CI run 40565205815](https://github.com/MSavisko/MouseMint/actions/runs/40565205815), which passed on release-PR commit `eef8f43d22f31430aa1c4b171154e3cb72515a51`. The duplicate PR-triggered run requires approval. This verifies release-note collection and the no-PAT dispatch path, including its approval limitation. Tag `v1.6.1` records the old development baseline at `3a19307` so generated comparisons have a real starting point; it is not a notarized app release.

[CI run 40563954089](https://github.com/MSavisko/MouseMint/actions/runs/40563954089) also passed the eight Python tests, 61 native tests, release build and DMG verification/upload.

After Keychain authorization, an isolated copy of MouseMint and all nested Sparkle helpers were signed with `Developer ID Application: Maksym Savisko (4KQC9K68AM)`. Deep strict signature verification, hardened runtime and the read-only native UI check passed. Gatekeeper rejected the copy with `source=Unnotarized Developer ID`, as expected before submission to Apple. Local evidence is saved in `.build/releases-developer-id-signing.json` and `.build/releases-developer-id-ui.log`; these generated files are not committed. No private key was exported by this check.

Apple notarization, final release publication and an actual update installation remain unverified. No notarized release has been published. These results must be recorded before calling the release setup complete.

## Sources

- [GitHub Actions free use and storage limits](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Standard hosted runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Installed Xcode 27 image software](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Release Please workflow and token behavior](https://github.com/googleapis/release-please-action)
- [Apple Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Sparkle setup and signing](https://sparkle-project.org/documentation/)
