#!/bin/bash
cd "$(dirname "$0")"
# Create App Bundle Structure
APP_NAME="TransPaste"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# App icon — generated as code (tools/generate_icon.swift), cached in build/
if [ ! -f build/AppIcon.icns ]; then
    ./tools/generate_icon.sh
fi
cp build/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

# Compile
swiftc -O Sources/*.swift -o "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and sync the version from AppInfo.swift (single source)
cp Info.plist "${CONTENTS_DIR}/Info.plist"
VERSION=$(grep -o 'version = "[^"]*"' Sources/AppInfo.swift | cut -d'"' -f2)
plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CONTENTS_DIR}/Info.plist"

# Set executable permissions
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Ad-hoc code signing to stabilize identity
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo "App Bundle created: ${BUNDLE_DIR}"
