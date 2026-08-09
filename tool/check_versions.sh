#!/usr/bin/env bash
# Fails when the package version is not the same everywhere it is declared.
#
# pubspec.yaml is the source of truth. The podspec and the Android build script
# carry their own copies, and they have silently drifted apart in the past.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

pubspec_version="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
podspec_version="$(grep -E "^\s*s\.version\s*=" ios/cunning_document_scanner.podspec | head -1 | sed -E "s/.*'([^']+)'.*/\1/")"
gradle_version="$(grep -E '^version\s*=' android/build.gradle.kts | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"

status=0

echo "pubspec.yaml            : $pubspec_version"
echo "ios/*.podspec           : $podspec_version"
echo "android/build.gradle.kts: $gradle_version"

if [ "$podspec_version" != "$pubspec_version" ]; then
  echo "::error::podspec version ($podspec_version) does not match pubspec ($pubspec_version)"
  status=1
fi

if [ "$gradle_version" != "$pubspec_version" ]; then
  echo "::error::android/build.gradle.kts version ($gradle_version) does not match pubspec ($pubspec_version)"
  status=1
fi

if ! grep -q "^## ${pubspec_version}$" CHANGELOG.md; then
  echo "::error::CHANGELOG.md has no '## ${pubspec_version}' entry"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "All versions agree on $pubspec_version"
fi

exit "$status"
