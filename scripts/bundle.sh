#!/bin/bash
set -euo pipefail

APP_NAME="Tappy"
BUILD_DIR=".build/release"
BUNDLE_DIR="build/${APP_NAME}.app/Contents"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
mkdir -p "${BUNDLE_DIR}/MacOS"
mkdir -p "${BUNDLE_DIR}/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE_DIR}/MacOS/"
cp Resources/Info.plist "${BUNDLE_DIR}/"
cp Resources/AppIcon.icns "${BUNDLE_DIR}/Resources/" 2>/dev/null || true

echo ""
echo "Done! Built: build/${APP_NAME}.app"
echo "Run:  open build/${APP_NAME}.app"
