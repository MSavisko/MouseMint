#!/bin/bash
# Only the trusted release job runs this script. Never enable shell tracing.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'Run this in the release workflow.' >&2; exit 1; }
: "${RELEASE_TAG:?}" "${SIGNING_IDENTITY:?}" "${SPARKLE_PRIVATE_KEY:?}"
app="$PWD/dist/MouseMint.app"
python3 Tools/release.py validate-app --tag "$RELEASE_TAG"
framework="$app/Contents/Frameworks/Sparkle.framework"
for nested in "$framework"/Versions/B/XPCServices/*.xpc "$framework/Versions/B/Updater.app" "$framework/Versions/B/Autoupdate" "$framework" "$app"; do
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$nested"
done
codesign --verify --deep --strict "$app"
notarize() {
  local target="$1" result="$2"
  xcrun notarytool submit "$target" --key "$RUNNER_TEMP/mousemint-notary.p8" \
    --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" \
    --wait --timeout 20m --output-format json > "$result"
  python3 - "$result" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status')!='Accepted': raise SystemExit('Notarization was not accepted: '+str(result.get('id')))
print('Notarization accepted: '+result['id'])
PY
}
mkdir -p .build/notarization
# Staple the app before making either user-facing archive.
ditto -c -k --sequesterRsrc --keepParent "$app" .build/notarization/MouseMint.zip
notarize .build/notarization/MouseMint.zip .build/notarization/app.json
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
python3 Tools/release.py package --tag "$RELEASE_TAG"
version="${RELEASE_TAG#v}"
dmg="dist/release/MouseMint-$version-arm64.dmg"
archive="dist/release/MouseMint-$version-arm64.zip"
codesign --timestamp --sign "$SIGNING_IDENTITY" "$dmg"
notarize "$dmg" .build/notarization/dmg.json
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
python3 Tools/verify-dmg.py "$dmg"
mkdir -p .build/update-feed
cp "$archive" .build/update-feed/
gh release view "$RELEASE_TAG" --json body --jq .body > ".build/update-feed/MouseMint-$version-arm64.md"
printf '%s' "$SPARKLE_PRIVATE_KEY" | Tuist/.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --ed-key-file - --maximum-deltas 0 --embed-release-notes \
  --download-url-prefix "https://github.com/$GH_REPO/releases/download/$RELEASE_TAG/" \
  .build/update-feed
cp .build/update-feed/appcast.xml dist/release/appcast.xml
python3 Tools/release.py validate-feed --tag "$RELEASE_TAG" --archive "$archive" --feed dist/release/appcast.xml
(cd dist/release && shasum -a 256 "MouseMint-$version-arm64.dmg" "MouseMint-$version-arm64.zip" appcast.xml > SHA256SUMS.txt)
# Keep the release draft until every artifact is notarized, stapled and signed.
gh release upload "$RELEASE_TAG" "$dmg" "$archive" dist/release/appcast.xml dist/release/SHA256SUMS.txt --clobber
gh release edit "$RELEASE_TAG" --draft=false --latest
