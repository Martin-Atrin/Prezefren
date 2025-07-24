#!/bin/bash

# Complete Release Packaging Script for Prezefren
# Builds, packages, and prepares everything for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configuration
APP_NAME="Prezefren"
APP_VERSION="1.0.15"
BUILD_NUMBER="1"
RELEASE_TYPE="${1:-release}"  # debug, release, or appstore

echo "🚀 Packaging ${APP_NAME} v${APP_VERSION} for ${RELEASE_TYPE} distribution..."

# Verify dependencies
echo "🔍 Verifying build dependencies..."
MISSING_DEPS=()

if [ ! -f "ggml-base.en.bin" ]; then
    MISSING_DEPS+=("ggml-base.en.bin (Whisper model)")
fi

if [ ! -d "Vendor/whisper.cpp/build" ]; then
    MISSING_DEPS+=("Whisper.cpp libraries (run make in Vendor/whisper.cpp)")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "❌ Missing dependencies:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Please resolve dependencies and try again."
    exit 1
fi

# Clean workspace
echo "🧹 Cleaning workspace..."
rm -rf build/
rm -rf dist/
mkdir -p dist/

# Step 1: Build application
echo "📦 Step 1: Building application..."
./build_distribution.sh "$RELEASE_TYPE"

if [ ! -d "build/${APP_NAME}.app" ]; then
    echo "❌ App build failed!"
    exit 1
fi

echo "✅ App built successfully"

# Step 2: Create DMG installer
echo "📦 Step 2: Creating DMG installer..."
./scripts/create_simple_dmg.sh

if [ ! -f "build/${APP_NAME}-${APP_VERSION}.dmg" ]; then
    echo "❌ DMG creation failed!"
    exit 1
fi

echo "✅ DMG created successfully"

# Step 3: Create additional distribution formats
echo "📦 Step 3: Creating additional distribution packages..."

# Create ZIP archive for GitHub releases
echo "🗜️ Creating ZIP archive..."
cd build
zip -r "../dist/${APP_NAME}-${APP_VERSION}.zip" "${APP_NAME}.app"
cd ..

# Create checksums
echo "🔐 Generating checksums..."
cd build
shasum -a 256 "${APP_NAME}-${APP_VERSION}.dmg" > "../dist/${APP_NAME}-${APP_VERSION}.dmg.sha256"
cd ../dist
shasum -a 256 "${APP_NAME}-${APP_VERSION}.zip" > "${APP_NAME}-${APP_VERSION}.zip.sha256"
cd ..

# Move DMG to dist
mv "build/${APP_NAME}-${APP_VERSION}.dmg" "dist/"

# Step 4: Generate release notes
echo "📝 Step 4: Generating release information..."
cat > "dist/RELEASE_NOTES.md" << EOF
# Prezefren v${APP_VERSION}

## 🎉 What's New

### Core Features
- **Real-time voice transcription** with advanced AI (Whisper base.en model)
- **Instant translation** to 10+ languages via Google Gemini API
- **Floating subtitle windows** with customizable templates
- **Dual audio mode** with stereo channel separation
- **Professional UI** with modern card-based design

### Key Capabilities
- **Out-of-the-box functionality** - no configuration needed
- **Multiple window templates** (Top Banner, Side Panel, Picture-in-Picture, etc.)
- **Enhanced translation engine** with toggle-based advanced features
- **Privacy-focused** with local transcription processing
- **Resource efficient** with smart memory management

## 📦 Installation

### Quick Install
1. Download \`${APP_NAME}-${APP_VERSION}.dmg\`
2. Open the DMG file
3. Drag Prezefren to Applications folder
4. Launch Prezefren from Applications
5. Grant microphone permission when prompted
6. Start speaking and enjoy real-time transcription!

### System Requirements
- **macOS**: 12.0 or later
- **Processor**: Apple Silicon or Intel
- **Memory**: 4 GB RAM (8 GB recommended)
- **Storage**: 500 MB available space
- **Audio**: Microphone required

## 🔧 Getting Started

1. **Set up translation** (optional):
   - Get free Google Gemini API key from https://makersuite.google.com/app/apikey
   - Create \`.env\` file with: \`GEMINI_API_KEY=your_key\`

2. **Configure windows**:
   - Use Windows tab to create floating subtitle windows
   - Choose from professional templates
   - Customize position, size, and opacity

3. **Start transcribing**:
   - Click the microphone button in Audio tab
   - Speak naturally - transcription appears in real-time
   - Enable translation for instant multilingual subtitles

## 🛡️ Privacy & Security

- **Local transcription**: Voice processing happens on your Mac
- **Optional cloud services**: Translation only when you choose
- **No telemetry**: Your conversations stay private
- **Open source**: Full transparency and community-driven development

## 📊 File Information

### Package Details
- **Version**: ${APP_VERSION} (Build ${BUILD_NUMBER})
- **Build Type**: ${RELEASE_TYPE}
- **Bundle Size**: $(du -h "build/${APP_NAME}.app" | cut -f1)
- **DMG Size**: $(du -h "dist/${APP_NAME}-${APP_VERSION}.dmg" | cut -f1)
- **ZIP Size**: $(du -h "dist/${APP_NAME}-${APP_VERSION}.zip" | cut -f1)

### Checksums
\`\`\`
$(cat "dist/${APP_NAME}-${APP_VERSION}.dmg.sha256")
$(cat "dist/${APP_NAME}-${APP_VERSION}.zip.sha256")
\`\`\`

## 🤝 Support

- **Documentation**: Check the app's Help menu
- **Issues**: [GitHub Issues](https://github.com/Martin-Atrin/Prezefren/issues)
- **Source Code**: [GitHub Repository](https://github.com/Martin-Atrin/Prezefren)

---

**Built with ❤️ for the global community**
EOF

# Step 5: Create installer verification script
echo "🔍 Step 5: Creating verification tools..."
cat > "dist/verify_installation.sh" << 'EOF'
#!/bin/bash

# Prezefren Installation Verifier
echo "🔍 Verifying Prezefren installation..."

APP_PATH="/Applications/Prezefren.app"

if [ -d "$APP_PATH" ]; then
    echo "✅ Prezefren.app found in Applications"
    
    # Check code signature
    if codesign -v "$APP_PATH" 2>/dev/null; then
        echo "✅ Code signature valid"
    else
        echo "⚠️  Code signature issues (expected for development builds)"
    fi
    
    # Check bundle structure
    if [ -f "$APP_PATH/Contents/MacOS/Prezefren" ]; then
        echo "✅ Executable found"
    else
        echo "❌ Executable missing"
    fi
    
    if [ -f "$APP_PATH/Contents/Resources/ggml-base.en.bin" ]; then
        echo "✅ Whisper model found"
    else
        echo "❌ Whisper model missing"
    fi
    
    # Check frameworks
    FRAMEWORKS="$APP_PATH/Contents/Frameworks"
    if [ -d "$FRAMEWORKS" ] && [ "$(ls -1 "$FRAMEWORKS"/*.dylib 2>/dev/null | wc -l)" -gt 0 ]; then
        echo "✅ Required frameworks found"
    else
        echo "❌ Missing frameworks"
    fi
    
    echo ""
    echo "🚀 Installation verification complete!"
    echo "You can now launch Prezefren from Applications or Launchpad."
    
else
    echo "❌ Prezefren.app not found in Applications"
    echo "Please install by dragging Prezefren.app to Applications folder"
fi
EOF

chmod +x "dist/verify_installation.sh"

# Final summary
echo ""
echo "🎉 Release packaging complete!"
echo ""
echo "📦 Distribution Files:"
echo "├── ${APP_NAME}-${APP_VERSION}.dmg ($(du -h "dist/${APP_NAME}-${APP_VERSION}.dmg" | cut -f1))"
echo "├── ${APP_NAME}-${APP_VERSION}.zip ($(du -h "dist/${APP_NAME}-${APP_VERSION}.zip" | cut -f1))"
echo "├── RELEASE_NOTES.md"
echo "├── verify_installation.sh"
echo "└── SHA256 checksums"
echo ""
echo "🚀 Ready for distribution!"
echo ""
echo "Next Steps:"
echo "1. Test installation: Open dist/${APP_NAME}-${APP_VERSION}.dmg"
echo "2. Upload to GitHub: Create release with DMG and ZIP"
echo "3. Update website: Add download links"
echo "4. Announce: Share with community"
echo ""
echo "📁 All files in: ./dist/"