#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mise exec -- tuist test MouseMint --no-selective-testing --no-binary-cache --no-upload \
  -- -destination 'platform=macOS,arch=arm64' -derivedDataPath "$PWD/.build/DerivedData" \
  -parallel-testing-enabled NO
