#!/bin/bash

# Navigate - macOS Logo Setup Script
# Generates app icons from logo.png for macOS
# Usage: ./logo_macos.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGO_SOURCE="$SCRIPT_DIR/logo.png"
LOGO_DEST="$SCRIPT_DIR/navigate/assets/app_icon.png"
NAVIGATE_DIR="$SCRIPT_DIR/navigate"
MACOS_ICONS_DIR="$NAVIGATE_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Navigate Logo Setup (macOS)"
echo "=================================="
echo ""

# Check if logo.png exists
if [ ! -f "$LOGO_SOURCE" ]; then
    echo "❌ Error: logo.png not found at $LOGO_SOURCE"
    echo "💡 Please ensure logo.png exists in the project root directory"
    exit 1
fi

echo "✓ Found logo.png"
echo ""

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter not found in PATH"
    echo "Checking for local Flutter installation..."
    
    FLUTTER_DIR="$SCRIPT_DIR/flutter"
    
    if [ ! -d "$FLUTTER_DIR" ]; then
        echo "❌ Error: Flutter not found and no local installation detected"
        echo "💡 Please install Flutter or run ./start_macos.sh first to clone Flutter SDK"
        exit 1
    fi
    
    # Add Flutter to PATH
    export PATH="$PATH:$FLUTTER_DIR/bin"
    
    if ! command -v flutter &> /dev/null; then
        echo "❌ Error: Flutter not found after adding to PATH"
        exit 1
    fi
fi

echo "✓ Flutter found"
echo ""

# Create assets directory if it doesn't exist
mkdir -p "$(dirname "$LOGO_DEST")"

# Copy logo to assets
echo "📋 Copying logo to assets..."
cp "$LOGO_SOURCE" "$LOGO_DEST"
echo "✓ Logo copied to $LOGO_DEST"
echo ""

# Generate macOS icons using sips
echo "🍎 Generating macOS icons..."

# Create macOS icons directory if it doesn't exist
mkdir -p "$MACOS_ICONS_DIR"

# Generate all required sizes
SIZES=(16 32 64 128 256 512 1024)

for SIZE in "${SIZES[@]}"; do
    OUTPUT_FILE="$MACOS_ICONS_DIR/app_icon_${SIZE}.png"
    if sips -z "$SIZE" "$SIZE" "$LOGO_DEST" --out "$OUTPUT_FILE" > /dev/null 2>&1; then
        echo "  ✓ Generated ${SIZE}x${SIZE} icon"
    else
        echo "  ⚠️  Warning: Failed to generate ${SIZE}x${SIZE} icon"
    fi
done

echo "✓ macOS icons generated"
echo ""

echo "✅ Logo setup complete!"
echo ""
echo "📦 Next steps:"
echo "   - Rebuild your app to see the new logo"
echo "   - Run: ./start_macos.sh"
echo ""

