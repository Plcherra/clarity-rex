#!/bin/sh
# Plaid ships LinkKit as a prebuilt binary without dSYMs. Xcode 16+ warns on
# TestFlight upload when the archive UUID for LinkKit.framework has no matching
# dSYM. Generate a UUID-matching dSYM so App Store Connect accepts the upload.
# Crash reports inside LinkKit still won't fully symbolicate (Plaid doesn't
# publish real DWARF), but your app/Flutter/Sentry symbols are unaffected.

set -eu

case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *)
    echo "note: Skipping LinkKit dSYM generation for ${CONFIGURATION:-unknown}"
    exit 0
    ;;
esac

case "${PLATFORM_NAME:-}" in
  iphoneos) ;;
  *)
    echo "note: Skipping LinkKit dSYM generation for ${PLATFORM_NAME:-unknown}"
    exit 0
    ;;
esac

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "warning: DWARF_DSYM_FOLDER_PATH is unset; skipping LinkKit dSYM generation"
  exit 0
fi

find_linkkit_binary() {
  candidates="
${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/LinkKit.framework/LinkKit
${BUILT_PRODUCTS_DIR}/LinkKit.framework/LinkKit
${BUILT_PRODUCTS_DIR}/PackageFrameworks/LinkKit.framework/LinkKit
"
  for candidate in $candidates; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # Fallback: search archive/build products for the device LinkKit binary.
  search_roots="
${TARGET_BUILD_DIR}
${BUILT_PRODUCTS_DIR}
${OBJROOT}
"
  for root in $search_roots; do
    [ -d "$root" ] || continue
    found="$(
      find "$root" \
        -path '*/LinkKit.framework/LinkKit' \
        -type f \
        ! -path '*/SourcePackages/*' \
        ! -path '*/ios-arm64_x86_64-*/*' \
        2>/dev/null | head -n 1 || true
    )"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  done

  return 1
}

LINKKIT_BIN="$(find_linkkit_binary || true)"
if [ -z "$LINKKIT_BIN" ]; then
  echo "warning: LinkKit.framework binary not found; skipping dSYM generation"
  exit 0
fi

mkdir -p "${DWARF_DSYM_FOLDER_PATH}"
DSYM_OUT="${DWARF_DSYM_FOLDER_PATH}/LinkKit.framework.dSYM"
rm -rf "${DSYM_OUT}"

echo "Generating LinkKit dSYM from ${LINKKIT_BIN}"
# Plaid strips DWARF from the shipped binary; dsymutil still emits a dSYM whose
# UUID matches the framework, which clears the App Store Connect warning.
xcrun dsymutil -o "${DSYM_OUT}" "${LINKKIT_BIN}" || {
  echo "warning: dsymutil failed for LinkKit; continuing archive"
  exit 0
}

if [ -d "${DSYM_OUT}" ]; then
  echo "Wrote ${DSYM_OUT}"
  xcrun dwarfdump --uuid "${DSYM_OUT}" || true
else
  echo "warning: LinkKit dSYM was not created"
fi
