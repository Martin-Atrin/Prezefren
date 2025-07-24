#!/bin/bash

# Prezefren Distribution Build Script
# Builds a distribution-ready macOS app with proper signing and packaging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Build configuration
APP_NAME="Prezefren"
APP_IDENTIFIER="com.prezefren.app"
APP_VERSION="1.0.12"
BUILD_NUMBER="1"
BUILD_TYPE="${1:-debug}"  # debug, release, or appstore

echo "🚀 Building Prezefren for distribution (${BUILD_TYPE})..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
mkdir -p build

# Verify dependencies
echo "🔍 Verifying dependencies..."
if [ ! -f "Vendor/whisper.cpp/build/src/libwhisper.dylib" ]; then
    echo "❌ Whisper libraries not found. Please build whisper.cpp first:"
    echo "   cd Vendor/whisper.cpp && make"
    exit 1
fi

if [ ! -f "ggml-base.en.bin" ]; then
    echo "❌ Whisper model not found. Please download ggml-base.en.bin"
    exit 1
fi

# Copy whisper libraries
echo "📦 Copying Whisper libraries..."
cp Vendor/whisper.cpp/build/src/libwhisper.dylib build/
cp Vendor/whisper.cpp/build/ggml/src/libggml.dylib build/
cp Vendor/whisper.cpp/build/ggml/src/libggml-cpu.dylib build/
cp Vendor/whisper.cpp/build/ggml/src/ggml-metal/libggml-metal.dylib build/

# Compile C bridge
echo "🔧 Compiling Whisper C bridge..."
clang -c whisper_bridge.c \
    -I./Vendor/whisper.cpp/include \
    -I./Vendor/whisper.cpp/ggml/include \
    -o build/whisper_bridge.o

# Create app bundle structure
echo "🏗️ Creating app bundle structure..."
APP_BUNDLE="build/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/"{MacOS,Resources,Frameworks}

# Create enhanced Info.plist for distribution
echo "📝 Creating distribution Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_IDENTIFIER}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Prezefren</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Prezefren needs microphone access for real-time voice transcription and translation</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Prezefren. All rights reserved.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
EOF

# Set optimization flags based on build type
OPTIMIZATION_FLAGS=""
SIGNING_IDENTITY=""

case "$BUILD_TYPE" in
    "release")
        OPTIMIZATION_FLAGS="-O -DNDEBUG"
        SIGNING_IDENTITY="Developer ID Application"
        echo "📦 Building release version with optimizations..."
        ;;
    "appstore")
        OPTIMIZATION_FLAGS="-O -DNDEBUG"
        SIGNING_IDENTITY="3rd Party Mac Developer Application"
        echo "🏪 Building App Store version..."
        ;;
    "debug")
        OPTIMIZATION_FLAGS="-Onone -g"
        SIGNING_IDENTITY="-"
        echo "🐛 Building debug version..."
        ;;
esac

# Compile Swift application
echo "🔧 Compiling Swift application..."
swiftc -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    PrezefrenApp.swift \
    Core/Models/AppState.swift \
    Core/Models/WindowTemplate.swift \
    Core/Engine/AudioEngine.swift \
    Core/Services/TranslationService.swift \
    Core/Services/EnhancedTranslationService.swift \
    Core/Services/EnvironmentConfig.swift \
    Core/Services/WindowConfigurationManager.swift \
    UI/Views/ContentView.swift \
    UI/Views/HelpView.swift \
    UI/Windows/FloatingPanel.swift \
    build/whisper_bridge.o \
    -framework SwiftUI \
    -framework AVFoundation \
    -framework Foundation \
    -framework AppKit \
    -L./build \
    -lwhisper \
    -lggml \
    -lggml-cpu \
    -lggml-metal \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -target arm64-apple-macos12.0 \
    $OPTIMIZATION_FLAGS

# Copy libraries to Frameworks directory
echo "📚 Installing frameworks..."
cp build/*.dylib "${APP_BUNDLE}/Contents/Frameworks/"

# Copy Whisper model to Resources (accessible via Bundle.main.path)
echo "🤖 Installing AI model..."
cp ggml-base.en.bin "${APP_BUNDLE}/Contents/Resources/"

# Fix library paths
echo "🔧 Fixing library paths..."
APP_EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
install_name_tool -change @rpath/libwhisper.1.dylib @executable_path/../Frameworks/libwhisper.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml.1.dylib @executable_path/../Frameworks/libggml.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml.dylib @executable_path/../Frameworks/libggml.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-cpu.dylib @executable_path/../Frameworks/libggml-cpu.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-metal.dylib @executable_path/../Frameworks/libggml-metal.dylib "$APP_EXECUTABLE" 2>/dev/null || true

# Create app icon (if available)
if [ -f "AppIcon.iconset" ]; then
    echo "🎨 Creating app icon..."
    iconutil -c icns AppIcon.iconset -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Sign the application
echo "🔐 Signing application..."
if [ "$BUILD_TYPE" = "debug" ]; then
    codesign --force --sign - --entitlements Prezefren.entitlements --deep "$APP_BUNDLE"
else
    # For release builds, use proper signing identity
    if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        codesign --force --sign "$SIGNING_IDENTITY" --entitlements Prezefren.entitlements --deep "$APP_BUNDLE"
        echo "✅ Signed with $SIGNING_IDENTITY"
    else
        echo "⚠️  Signing identity '$SIGNING_IDENTITY' not found, using ad-hoc signing"
        codesign --force --sign - --entitlements Prezefren.entitlements --deep "$APP_BUNDLE"
    fi
fi

# Verify the build
echo "🔍 Verifying build..."
codesign -vvv --deep --strict "$APP_BUNDLE"
if [ $? -eq 0 ]; then
    echo "✅ Code signature verification passed"
else
    echo "⚠️  Code signature verification failed"
fi

# Create DMG for distribution (release builds only)
if [ "$BUILD_TYPE" = "release" ] || [ "$BUILD_TYPE" = "appstore" ]; then
    echo "📦 Creating distribution package..."
    
    # Create DMG
    DMG_NAME="Prezefren-${APP_VERSION}.dmg"
    hdiutil create -volname "Prezefren" -srcfolder "$APP_BUNDLE" -ov -format UDZO "build/${DMG_NAME}"
    
    echo "📦 Distribution package created: build/${DMG_NAME}"
fi

# Calculate app size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)

echo ""
echo "🎉 Build completed successfully!"
echo "📱 App: $APP_BUNDLE"
echo "📏 Size: $APP_SIZE"
echo "🔢 Version: $APP_VERSION ($BUILD_NUMBER)"
echo "🏗️ Type: $BUILD_TYPE"
echo ""
echo "🚀 To run: open '$APP_BUNDLE'"

if [ "$BUILD_TYPE" = "release" ] || [ "$BUILD_TYPE" = "appstore" ]; then
    echo "📦 Distribution package: build/Prezefren-${APP_VERSION}.dmg"
fi

echo ""
echo "✅ Prezefren is ready for distribution!"