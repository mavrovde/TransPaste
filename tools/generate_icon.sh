#!/bin/bash
# Renders the app icon (tools/generate_icon.swift) into build/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
mkdir -p build
rm -rf "${ICONSET}"
swift tools/generate_icon.swift "${ICONSET}"
iconutil -c icns "${ICONSET}" -o build/AppIcon.icns
rm -rf "${ICONSET}"
echo "Icon created: build/AppIcon.icns"
