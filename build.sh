#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/module-cache "dist/Keychron Charge.app/Contents/MacOS" "dist/Keychron Charge.app/Contents/Resources"
xcrun swiftc -O -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 \
  Sources/*.swift \
  -o "dist/Keychron Charge.app/Contents/MacOS/KeychronCharge"
cp Resources/Info.plist "dist/Keychron Charge.app/Contents/Info.plist"
codesign --force --sign - "dist/Keychron Charge.app"
echo "Built: $PWD/dist/Keychron Charge.app"
