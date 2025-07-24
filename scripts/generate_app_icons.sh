#!/bin/bash

# Generate App Icons for macOS App Store
# Requires a source image (preferably 1024x1024 PNG)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_IMAGE="${1:-app_icon_source.png}"
OUTPUT_DIR="${SCRIPT_DIR}/../AppIcon.iconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    echo "Usage: $0 [source_image.png]"
    echo ""
    echo "Please provide a high-quality 1024x1024 PNG image as the source."
    echo "The image should:"
    echo "  • Be square (1:1 aspect ratio)"
    echo "  • Have transparent or appropriate background"
    echo "  • Be clear and recognizable at small sizes"
    echo "  • Follow Apple's app icon guidelines"
    exit 1
fi

echo "🎨 Generating App Icons from: $SOURCE_IMAGE"

# Check if ImageMagick is available
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install imagemagick
    else
        echo "❌ Please install ImageMagick first:"
        echo "   brew install imagemagick"
        exit 1
    fi
fi

# Create iconset directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Required icon sizes for macOS
declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

echo "📏 Generating icon sizes..."

for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    echo "  • ${size}x${size} → $filename"
    
    convert "$SOURCE_IMAGE" -resize "${size}x${size}" "$OUTPUT_DIR/$filename"
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to generate $filename"
        exit 1
    fi
done

# Generate the .icns file
echo "🔧 Creating .icns file..."
iconutil -c icns "$OUTPUT_DIR"

if [ $? -eq 0 ]; then
    echo "✅ App icon generated successfully!"
    echo "📁 Icon files: $OUTPUT_DIR"
    echo "📦 App icon: $(dirname "$OUTPUT_DIR")/AppIcon.icns"
    
    # Verify the generated icons
    echo ""
    echo "🔍 Generated files:"
    ls -la "$OUTPUT_DIR"
    
    if [ -f "$(dirname "$OUTPUT_DIR")/AppIcon.icns" ]; then
        icns_size=$(stat -f%z "$(dirname "$OUTPUT_DIR")/AppIcon.icns")
        echo "📦 AppIcon.icns size: $icns_size bytes"
    fi
else
    echo "❌ Failed to create .icns file"
    exit 1
fi

echo ""
echo "🎉 App icon generation complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated icons to ensure quality"
echo "2. Test the .icns file in your app bundle"
echo "3. Update your app's Info.plist to reference the icon"
echo "4. Add CFBundleIconFile key if not present"