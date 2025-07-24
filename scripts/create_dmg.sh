#!/bin/bash

# Professional DMG Creator for Prezefren
# Creates a beautiful, branded DMG installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configuration
APP_NAME="Prezefren"
APP_VERSION="1.0.15"
DMG_NAME="Prezefren-${APP_VERSION}"
SOURCE_APP="build/${APP_NAME}.app"
DMG_DIR="build/dmg"
TEMP_DMG="build/temp_${DMG_NAME}.dmg"
FINAL_DMG="build/${DMG_NAME}.dmg"

echo "📦 Creating professional DMG installer for ${APP_NAME} v${APP_VERSION}..."

# Verify source app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ App bundle not found: $SOURCE_APP"
    echo "Please run ./build_distribution.sh first"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous DMG builds..."
rm -rf "$DMG_DIR"
rm -f "$TEMP_DMG"
rm -f "$FINAL_DMG"
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
echo "📁 Copying app bundle..."
cp -R "$SOURCE_APP" "$DMG_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$DMG_DIR/Applications"

# Create README file for DMG
echo "📝 Creating installation instructions..."
cat > "$DMG_DIR/README.txt" << 'EOF'
Prezefren - Real-Time Voice Translation

INSTALLATION:
1. Drag Prezefren.app to the Applications folder
2. Open Prezefren from Applications or Launchpad
3. Grant microphone permission when prompted
4. Start speaking and enjoy real-time transcription!

FEATURES:
• Real-time voice transcription with AI
• Instant translation to multiple languages  
• Floating subtitle windows
• Dual audio mode for stereo processing
• Professional window templates
• Privacy-focused with local processing

SUPPORT:
• Documentation: Check the app's Help menu
• Issues: https://github.com/Martin-Atrin/Prezefren/issues
• Website: Coming soon

Thank you for using Prezefren!
EOF

# Create DMG background and styling (if we have assets)
USE_BACKGROUND=false
if [ -f "assets/dmg_background.png" ]; then
    echo "🎨 Adding DMG background..."
    mkdir -p "$DMG_DIR/.background"
    cp "assets/dmg_background.png" "$DMG_DIR/.background/"
    USE_BACKGROUND=true
fi

# Calculate required DMG size (add 50MB buffer)
APP_SIZE=$(du -sm "$SOURCE_APP" | cut -f1)
DMG_SIZE=$((APP_SIZE + 50))

echo "📏 App size: ${APP_SIZE}MB, DMG size: ${DMG_SIZE}MB"

# Create temporary DMG
echo "🔧 Creating temporary DMG..."
hdiutil create -srcfolder "$DMG_DIR" -volname "$APP_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW -size "${DMG_SIZE}m" "$TEMP_DMG"

# Mount temporary DMG
echo "💿 Mounting DMG for customization..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" | \
    egrep '^/dev/' | sed 1q | awk '{print $3}')

# Customize DMG appearance with AppleScript
echo "🎨 Customizing DMG appearance..."

if [ "$USE_BACKGROUND" = "true" ]; then
    osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:dmg_background.png"
        
        -- Position icons
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {350, 200}
        
        -- Hide README initially
        try
            set position of item "README.txt" of container window to {150, 300}
        end try
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
else
    osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 580, 350}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        
        -- Position icons in clean layout
        set position of item "$APP_NAME.app" of container window to {140, 150}
        set position of item "Applications" of container window to {350, 150}
        set position of item "README.txt" of container window to {245, 250}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
fi

# Finalize DMG permissions
echo "🔒 Setting DMG permissions..."
chmod -Rf go-w "$MOUNT_DIR"
sync

# Unmount DMG
echo "📤 Unmounting DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to final compressed DMG
echo "🗜️ Creating final compressed DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_DIR"

# Verify final DMG
if [ -f "$FINAL_DMG" ]; then
    FINAL_SIZE=$(du -h "$FINAL_DMG" | cut -f1)
    echo ""
    echo "✅ DMG created successfully!"
    echo "📦 File: $FINAL_DMG"
    echo "📏 Size: $FINAL_SIZE"
    echo ""
    echo "🧪 Testing DMG..."
    hdiutil verify "$FINAL_DMG"
    echo "✅ DMG verification passed!"
    echo ""
    echo "🚀 Ready for distribution!"
    echo "📤 Upload to: GitHub Releases, website, etc."
else
    echo "❌ DMG creation failed!"
    exit 1
fi