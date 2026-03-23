#!/bin/bash
set -euo pipefail

APP_NAME="Tappy"
VERSION="${1:-0.6}"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
BUILD_DIR="build"

# Ensure app is built
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    echo "Error: ${BUILD_DIR}/${APP_NAME}.app not found. Run bundle.sh first."
    exit 1
fi

# Remove old DMG
rm -f "${BUILD_DIR}/${DMG_NAME}"

create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 540 430 \
    --icon-size 80 \
    --icon "${APP_NAME}.app" 140 190 \
    --app-drop-link 400 190 \
    --background "Resources/dmg-background.png" \
    --hide-extension "${APP_NAME}.app" \
    --text-size 14 \
    --no-internet-enable \
    "${BUILD_DIR}/${DMG_NAME}" \
    "${BUILD_DIR}/${APP_NAME}.app"

echo ""
echo "Done! Created: ${BUILD_DIR}/${DMG_NAME}"
