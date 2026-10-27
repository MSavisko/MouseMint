# Source from the project root before invoking Tuist. Its manifest cache hashes
# TUIST_* variables, so metadata-only changes invalidate the cached project.
mousemint_version_value="$(cat version.txt)"
export TUIST_MOUSEMINT_VERSION="$mousemint_version_value"
mousemint_public_key_value="$(cat Resources/SparklePublicKey.txt)"
export TUIST_MOUSEMINT_PUBLIC_KEY="$mousemint_public_key_value"
