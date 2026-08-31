#!/bin/sh
set -eu

# `flutter build ios --no-codesign` uses ACTION=build and is allowed as a
# source/compile check. Xcode Archive uses ACTION=install and must have the
# institution-owned identity and Apple team.
if [ "${ACTION:-build}" != "install" ] && [ "${NUTRISENSE_ENFORCE_SIGNING_GUARD:-0}" != "1" ]; then
  exit 0
fi

case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
  com.example.*|"")
    echo "error: Archive blocked: set the institution-owned NUTRISENSE_BUNDLE_ID."
    exit 1
    ;;
esac

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "error: Archive blocked: select the authorized Apple Development Team."
  exit 1
fi
