#!/bin/bash

# Navigate - Linux Logo Setup Script
# Generates app icons from logo.png for Linux
# Usage: ./logo_linux.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGO_SOURCE="$SCRIPT_DIR/logo.png"
LOGO_DEST="$SCRIPT_DIR/navigate/assets/app_icon.png"
NAVIGATE_DIR="$SCRIPT_DIR/navigate"

echo "🎨 Navigate Logo Setup (Linux)"
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
        echo "💡 Please install Flutter or run ./start_linux.sh first to clone Flutter SDK"
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

# Navigate to Flutter project
cd "$NAVIGATE_DIR"

echo "🐧 Generating Linux icons..."
echo "   Note: Linux icons are typically handled by the desktop entry or packaging."
echo "   Ensuring the asset exists is the main step here."
echo ""

echo "✅ Logo setup complete!"
echo ""
echo "📦 Next steps:"
echo "   - Rebuild your app to see the new logo"
echo "   - Run: ./start_linux.sh"
echo ""

