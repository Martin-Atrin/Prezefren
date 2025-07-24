#!/bin/bash

# Simple DMG Creator for Prezefren
# Creates a basic but functional DMG installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configuration
APP_NAME="Prezefren"
APP_VERSION="1.0.15"
SOURCE_APP="build/${APP_NAME}.app"
FINAL_DMG="build/${APP_NAME}-${APP_VERSION}.dmg"

echo "📦 Creating simple DMG installer for ${APP_NAME} v${APP_VERSION}..."

# Verify source app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ App bundle not found: $SOURCE_APP"
    echo "Please run ./build_distribution.sh first"
    exit 1
fi

# Clean previous DMG
rm -f "$FINAL_DMG"

# Create DMG directly from app
echo "🔧 Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$SOURCE_APP" -ov -format UDZO "$FINAL_DMG"

# Verify DMG
if [ -f "$FINAL_DMG" ]; then
    DMG_SIZE=$(du -h "$FINAL_DMG" | cut -f1)
    echo ""
    echo "✅ DMG created successfully!"
    echo "📦 File: $FINAL_DMG"
    echo "📏 Size: $DMG_SIZE"
    echo ""
    echo "🧪 Testing DMG..."
    hdiutil verify "$FINAL_DMG"
    echo "✅ DMG verification passed!"
else
    echo "❌ DMG creation failed!"
    exit 1
fi