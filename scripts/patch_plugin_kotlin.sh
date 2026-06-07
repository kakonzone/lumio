#!/usr/bin/env bash
# Flutter plugins often pin kotlin_version in android/build.gradle (e.g. 2.1.10).
# Root Gradle hooks cannot always override that before buildscript resolves.
set -euo pipefail

KOTLIN_VERSION="${KOTLIN_VERSION:-2.3.0}"
PUB_CACHE="${PUB_CACHE:-${HOME}/.pub-cache}"
SEARCH_ROOT="${PUB_CACHE}/hosted/pub.dev"

if [[ ! -d "${SEARCH_ROOT}" ]]; then
  echo "pub-cache not found at ${SEARCH_ROOT}; skipping plugin Kotlin patch"
  exit 0
fi

patched=0
while IFS= read -r -d '' file; do
  if grep -qE 'kotlin_version\s*=\s*['\''"][0-9.]+['\''"]' "${file}"; then
    sed -i -E "s/(kotlin_version\s*=\s*['\"])[0-9.]+(['\"])/\1${KOTLIN_VERSION}\2/g" "${file}"
    echo "patched ${file}"
    patched=$((patched + 1))
  fi
done < <(find "${SEARCH_ROOT}" -path '*/android/build.gradle' ! -path '*/example/*' -print0 2>/dev/null)

echo "Patched ${patched} plugin build.gradle file(s) to Kotlin ${KOTLIN_VERSION}"
