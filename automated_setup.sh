#!/bin/bash

# Prefer the installed copy (DMG install); fall back to the dev build
if [ -d "/Applications/TransPaste.app" ]; then
    APP_PATH="/Applications/TransPaste.app"
else
    APP_PATH="$(pwd)/build/TransPaste.app"
fi
BUNDLE_ID="com.mavrovde.transpaste"
echo "Target app: ${APP_PATH}"

echo "=== Automating Permission Setup ==="

# 1. Kill App
echo "1. Closing App..."
pkill -9 -x TransPaste

# 2. Reset Permissions
echo "2. Resetting Permissions for ${BUNDLE_ID}..."
tccutil reset InputMonitoring "${BUNDLE_ID}"
tccutil reset Accessibility "${BUNDLE_ID}"

# 3. Open System Settings
echo "3. Opening System Settings > Input Monitoring..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

# 4. Reveal App in Finder
echo "4. Revealing App in Finder..."
open -R "${APP_PATH}"

# 5. Instructions
echo ""
echo "!!! ACTION REQUIRED !!!"
echo "---------------------------------------------------"
echo "1. Drag 'TransPaste' from the FINDER window..."
echo "2. ...into the SYSTEM SETTINGS window list."
echo "3. Make sure the toggle is ON."
echo "---------------------------------------------------"
echo "Press ENTER when done to launch the app..."
read

# 6. Launch App
echo "6. Launching App..."
open "${APP_PATH}"

echo "Done."
