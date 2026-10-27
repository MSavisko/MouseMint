#!/bin/bash
set -euo pipefail
: "${RELEASE_TAG:?}" "${RELEASE_COMMIT:?}" "${GH_REPO:?}"
[[ "$RELEASE_COMMIT" =~ ^[0-9a-f]{40}$ ]]
test "$(git rev-parse HEAD)" = "$RELEASE_COMMIT"
git merge-base --is-ancestor HEAD origin/main
test "$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft)" = true
test "$(gh release view "$RELEASE_TAG" --json targetCommitish --jq .targetCommitish)" = "$RELEASE_COMMIT"
