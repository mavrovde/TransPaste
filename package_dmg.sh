#!/bin/bash
# Creates build/TransPaste-<version>.dmg — a standard drag-to-Applications
# disk image (app + /Applications symlink, compressed UDZO).
# Uses build/TransPaste.app, building it first if missing.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/TransPaste.app"
[ -d "$APP" ] || ./build.sh

VERSION=$(grep -o 'version = "[^"]*"' Sources/AppInfo.swift | cut -d'"' -f2)
DMG="build/TransPaste-${VERSION}.dmg"
STAGING="build/dmg-staging"

rm -rf "${STAGING}" "${DMG}"
mkdir -p "${STAGING}"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

hdiutil create -volname "TransPaste ${VERSION}" \
    -srcfolder "${STAGING}" -ov -format UDZO "${DMG}"

rm -rf "${STAGING}"
echo "DMG created: ${DMG}"
