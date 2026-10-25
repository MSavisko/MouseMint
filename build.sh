#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/module-cache "dist/MouseMint.app/Contents/MacOS" "dist/MouseMint.app/Contents/Resources"
xcrun swiftc -O -module-cache-path .build/module-cache -target arm64-apple-macosx13.0 \
  Sources/*.swift \
  -o "dist/MouseMint.app/Contents/MacOS/MouseMint"
cp Resources/Info.plist "dist/MouseMint.app/Contents/Info.plist"
cp LICENSE "dist/MouseMint.app/Contents/Resources/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "dist/MouseMint.app/Contents/Resources/THIRD_PARTY_NOTICES.md"
codesign --force --sign - "dist/MouseMint.app"
echo "Built: $PWD/dist/MouseMint.app"
