#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
source Tools/project-environment.sh
mise exec -- tuist install
mise exec -- tuist generate --no-open
