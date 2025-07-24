#!/bin/bash

echo "Building Prezefren v1.0.15 macOS app with record-to-file feature and native sample rate support..."

# Create build directory
mkdir -p build

# Copy whisper libraries from pre-built vendor
echo "📦 Copying Whisper libraries..."
cp Vendor/whisper.cpp/build/src/libwhisper.dylib build/ 2>/dev/null || echo "⚠️  Whisper library not found - run make in Vendor/whisper.cpp first"
cp Vendor/whisper.cpp/build/ggml/src/libggml.dylib build/ 2>/dev/null || echo "⚠️  GGML library not found"
cp Vendor/whisper.cpp/build/ggml/src/libggml-base.dylib build/ 2>/dev/null || echo "⚠️  GGML Base library not found"
cp Vendor/whisper.cpp/build/ggml/src/libggml-cpu.dylib build/ 2>/dev/null || echo "⚠️  GGML CPU library not found"
cp Vendor/whisper.cpp/build/ggml/src/ggml-metal/libggml-metal.dylib build/ 2>/dev/null || echo "⚠️  GGML Metal library not found"
cp Vendor/whisper.cpp/build/ggml/src/ggml-blas/libggml-blas.dylib build/ 2>/dev/null || echo "⚠️  GGML BLAS library not found"

# Compile C bridge with whisper.cpp
echo "🔧 Compiling real Whisper C bridge..."
clang -c whisper_bridge.c \
    -I./Vendor/whisper.cpp/include \
    -I./Vendor/whisper.cpp/ggml/include \
    -target arm64-apple-macos13.0 \
    -o build/whisper_bridge.o

# Build Virtual Audio System (v1.1.0) - OPTIONAL
echo "🔧 Virtual Audio System (Professional mode - optional)..."
echo "ℹ️ Virtual audio plugin has compilation issues - using fallback mode"
echo "ℹ️ Main app includes virtual audio integration with automatic fallback"

# Create app bundle structure
echo "🔧 Creating macOS app bundle..."
mkdir -p build/Prezefren.app/Contents/{MacOS,Resources}

# Create Info.plist for proper GUI app
cat > build/Prezefren.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Prezefren</string>
    <key>CFBundleIdentifier</key>
    <string>com.prezefren.app</string>
    <key>CFBundleName</key>
    <string>Prezefren</string>
    <key>CFBundleVersion</key>
    <string>1.0.15</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Prezefren needs microphone access for real-time transcription</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Prezefren uses speech recognition for real-time transcription of audio input</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
EOF

# Build the Swift app with real Whisper integration
echo "🔧 Compiling Swift app with real Whisper..."
swiftc -o build/Prezefren.app/Contents/MacOS/Prezefren \
    PrezefrenApp.swift \
    Core/Models/AppState.swift \
    Core/Models/WindowTemplate.swift \
    Core/Engine/SimpleAudioEngine.swift \
    Core/Engine/AudioDeviceManager.swift \
    Core/Services/EnhancedTranslationService.swift \
    Core/Services/AssemblyAITranscriptionService.swift \
    Core/Services/WhisperModelManager.swift \
    Core/Services/EnvironmentConfig.swift \
    Core/Services/WindowConfigurationManager.swift \
    Core/Services/LanguageService.swift \
    Core/Preferences/PreferencesManager.swift \
    Core/Debug/DebugLogger.swift \
    Core/Debug/ResourceMonitor.swift \
    Core/MenuBar/MenuBarManager.swift \
    Core/Audio/AudioRecorder.swift \
    UI/Views/ContentView.swift \
    UI/Views/HelpView.swift \
    UI/Views/ModelsView.swift \
    UI/Preferences/PreferencesWindow.swift \
    UI/Preferences/AppleTranslationIntegration.swift \
    UI/Windows/FloatingPanel.swift \
    UI/Debug/DebugConsoleView.swift \
    UI/Components/SearchableLanguagePicker.swift \
    UI/Components/AnimatedTextView.swift \
    UI/Components/WordStreamingService.swift \
    UI/Components/ProgressiveTextView.swift \
    PrezefrenTheme.swift \
    build/whisper_bridge.o \
    -framework SwiftUI \
    -framework AVFoundation \
    -framework Foundation \
    -framework AppKit \
    -framework CoreAudio \
    -framework Translation \
    -L./build \
    -lwhisper \
    -lggml \
    -lggml-base \
    -lggml-cpu \
    -lggml-metal \
    -lggml-blas \
    -Xlinker -rpath -Xlinker @executable_path/../../../ \
    -target arm64-apple-macos13.0

# Copy libraries to app bundle
cp build/*.dylib build/Prezefren.app/Contents/MacOS/

# Fix library paths using install_name_tool BEFORE signing
echo "🔧 Fixing library paths..."
APP_EXECUTABLE="build/Prezefren.app/Contents/MacOS/Prezefren"
install_name_tool -change @rpath/libwhisper.1.dylib @executable_path/libwhisper.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml.1.dylib @executable_path/libggml.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml.dylib @executable_path/libggml.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-base.dylib @executable_path/libggml-base.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-cpu.dylib @executable_path/libggml-cpu.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-metal.dylib @executable_path/libggml-metal.dylib "$APP_EXECUTABLE" 2>/dev/null || true
install_name_tool -change @rpath/libggml-blas.dylib @executable_path/libggml-blas.dylib "$APP_EXECUTABLE" 2>/dev/null || true

# Copy model file to app bundle Resources (use multilingual model for language support)
cp ggml-base.bin build/Prezefren.app/Contents/Resources/

# Copy Python scripts to app bundle Resources
mkdir -p build/Prezefren.app/Contents/Resources/Scripts
cp Scripts/nllb_translator.py build/Prezefren.app/Contents/Resources/Scripts/

# Sign app with microphone entitlements
echo "🔐 Signing app with microphone entitlements..."
codesign --force --sign - --entitlements Prezefren.entitlements "$APP_EXECUTABLE"

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "Run with: ./build/Prezefren.app/Contents/MacOS/Prezefren"
    echo "Or bundled: open build/Prezefren.app"
    echo ""
    echo "🎯 Prezefren v1.0.15 Features:"
    echo "• 🪟 Multiple floating subtitle windows"
    echo "• 🔄 Simple vs Additive text modes"
    echo "• 🎙️ NEW: Record-to-file with native sample rate support (44.1kHz/48kHz)"
    echo "• 🌍 Dynamic language selection based on transcription/translation engines"
    echo "• 🎧 Clean dual channel L/R separation with VAD protection"
    echo "• 🔄 Unified rate limiting eliminates channel conflicts"
    echo "• 🌊 Sequential processing prevents race conditions"
    echo "• 🚫 Anti-hallucination technology with VAD-based processing"
    echo "• 🔇 Smart silence mode prevents background noise processing"
    echo "• 🎯 Quality-gated context preservation with speech detection"
    echo "• 🎧 Device-agnostic audio mode processing (mono/goobero)"
    echo "• 🔀 NATIVE: Simplified passthrough using macOS native audio routing"
    echo "• 🔊 Goobero mode ready (enhanced dual channel when stereo hardware available)"
    echo "• 📊 Seamless 3-second processing intervals with extended context"
    echo "• 🔤 Improved first-word capture with rolling window system"
    echo "• 🗂️ Context-aware transcription with natural speech boundaries"
    echo "• 🌍 Translation via Gemini 1.5 Flash API"
    echo "• 🎨 NEW: Modern glassmorphic theme with gradient buttons and animated status indicators"
    echo "• 📏 NEW: Extended font size support up to 72pt for subtitle windows"
    echo "• ✨ NEW: Buttery smooth word-by-word text animations (like professional subtitles)"
    echo "• 🎯 NEW: Fixed Goobero mode with proper 3.5-second buffer processing"
    echo "• 🧠 NEW: Intelligent language capabilities service (99 Whisper, 30+ Apple, English-only AssemblyAI)"
    echo "• 📱 NEW: Runtime Apple Translation availability checking (macOS 15.0+)"
    echo "• ⚡ Fast CLI-based build system"
else
    echo "❌ Build failed!"
    exit 1
fi