#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./generate.sh
xcodebuild -workspace MouseMint.xcworkspace -scheme MouseMint -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/DerivedData build
mkdir -p dist
# Replace the generated bundle so removed resources cannot survive a rebuild.
rm -rf dist/MouseMint.app
ditto .build/DerivedData/Build/Products/Release/MouseMint.app dist/MouseMint.app
codesign --verify --strict dist/MouseMint.app
echo "Built: $PWD/dist/MouseMint.app"
