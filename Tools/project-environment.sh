# Source from the project root before invoking Tuist. Its manifest cache hashes
# TUIST_* variables, so metadata-only changes invalidate the cached project.
export TUIST_MOUSEMINT_VERSION="$(cat version.txt)"
export TUIST_MOUSEMINT_PUBLIC_KEY="$(cat Resources/SparklePublicKey.txt)"
