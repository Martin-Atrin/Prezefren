#!/bin/bash

echo "🎵 Building Prezefren Virtual Audio System..."

# Set up build environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/Build"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
BUILD_TYPE="Release"
INSTALL_PLUGIN=false
CLEAN_BUILD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --install)
            INSTALL_PLUGIN=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --debug     Build in debug mode"
            echo "  --install   Install plugin to system after build"
            echo "  --clean     Clean build directory first"
            echo "  --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📁 Build directory: $BUILD_DIR"
echo "🔧 Build type: $BUILD_TYPE"

# Check if cmake is available
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install cmake
    else
        echo "❌ Homebrew not found. Please install CMake manually:"
        echo "   https://cmake.org/download/"
        exit 1
    fi
fi

# Configure with CMake
echo "⚙️ Configuring project with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="12.0"

if [ $? -ne 0 ]; then
    echo "❌ CMake configuration failed!"
    exit 1
fi

# Build the project
echo "🔨 Building virtual audio plugin..."
cmake --build . --config "$BUILD_TYPE" --parallel

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Virtual audio plugin built successfully!"

# Show what was built
if [ -d "PrezefrenVirtualAudio.plugin" ]; then
    echo "📦 Built plugin: $(pwd)/PrezefrenVirtualAudio.plugin"
    echo "🗂️ Plugin contents:"
    ls -la PrezefrenVirtualAudio.plugin/Contents/
else
    echo "⚠️ Plugin bundle not found at expected location"
fi

# Install plugin if requested
if [ "$INSTALL_PLUGIN" = true ]; then
    echo "🔧 Installing plugin to system..."
    
    # Check if plugin directory exists
    PLUGIN_DIR="/Library/Audio/Plug-Ins/HAL"
    if [ ! -d "$PLUGIN_DIR" ]; then
        echo "📁 Creating HAL plugin directory..."
        sudo mkdir -p "$PLUGIN_DIR"
    fi
    
    # Remove existing plugin if present
    if [ -d "$PLUGIN_DIR/PrezefrenVirtualAudio.plugin" ]; then
        echo "🗑️ Removing existing plugin..."
        sudo rm -rf "$PLUGIN_DIR/PrezefrenVirtualAudio.plugin"
    fi
    
    # Install new plugin
    echo "📥 Installing new plugin..."
    sudo cp -R "PrezefrenVirtualAudio.plugin" "$PLUGIN_DIR/"
    
    if [ $? -eq 0 ]; then
        echo "✅ Plugin installed successfully!"
        echo "🎯 Virtual audio devices will appear in Audio MIDI Setup after restarting Core Audio"
        echo "💡 To restart Core Audio: sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod"
    else
        echo "❌ Plugin installation failed!"
        exit 1
    fi
fi

# Integration instructions
echo ""
echo "🎯 Next Steps:"
echo "1. The virtual audio plugin is ready for integration"
echo "2. Add VirtualAudioIntegration.h to your AudioEngine"
echo "3. Enable virtual audio in preferences to test"
echo "4. The system will automatically fall back to current audio if virtual audio fails"
echo ""
echo "🔍 Testing:"
echo "- Check Audio MIDI Setup for 'Prezefren' devices (after installation)"
echo "- Enable virtual audio in Prezefren preferences" 
echo "- Monitor console logs for virtual audio status"
echo ""
echo "📚 Documentation: VirtualAudioDevice/Examples/AudioEngineIntegration.md"