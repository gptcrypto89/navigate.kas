#!/bin/bash

# Navigate - macOS Release Build Script
# Builds release versions of the app for distribution on macOS
# Usage: ./release_macos.sh [--skip-build]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BUILD=false
RELEASE_DIR="$SCRIPT_DIR/release"
NAVIGATE_DIR="$SCRIPT_DIR/navigate"
PLATFORM="macos"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: ./release_macos.sh [--skip-build]"
            exit 1
            ;;
    esac
done

echo "📦 Navigate Release Build (macOS)"
echo "=================================="
echo ""
echo "Release directory: $RELEASE_DIR"
echo ""

# Setup Flutter environment
FLUTTER_DIR="$SCRIPT_DIR/flutter"
if [ -d "$FLUTTER_DIR" ]; then
    export PATH="$FLUTTER_DIR/bin:$PATH"
fi

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter not found in PATH"
    echo "Cloning Flutter SDK..."
    
    FLUTTER_DIR="$SCRIPT_DIR/flutter"
    
    # Clone Flutter if not exists
    if [ ! -d "$FLUTTER_DIR" ]; then
        echo "📥 Cloning Flutter SDK..."
        git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    fi
    
    # Add Flutter to PATH
    export PATH="$FLUTTER_DIR/bin:$PATH"
    
    if ! command -v flutter &> /dev/null; then
        echo "❌ Error: Flutter not found after cloning."
        exit 1
    fi
fi

echo "✓ Flutter found"
echo ""

# Build native libraries if needed
if [ "$SKIP_BUILD" = false ]; then
    echo "🔧 Building secp256k1 native libraries..."
    echo ""
    
    SECP256K1_DIR="$SCRIPT_DIR/secp256k1"
    
    # Clone secp256k1 if not exists
    if [ ! -d "$SECP256K1_DIR" ]; then
        echo "📥 Cloning secp256k1 from bitcoin-core (tag v0.7.0)..."
        git clone https://github.com/bitcoin-core/secp256k1.git "$SECP256K1_DIR"
        cd "$SECP256K1_DIR"
        git checkout v0.7.0
        cd "$SCRIPT_DIR"
    fi
    
    cd "$SECP256K1_DIR" || {
        echo "❌ Failed to change to secp256k1 directory: $SECP256K1_DIR"
        exit 1
    }
    
    # Generate configure script if needed
    if [ ! -f "configure" ]; then
        echo "🔨 Generating build configuration..."
        if [ ! -f "autogen.sh" ]; then
            echo "❌ autogen.sh not found in $SECP256K1_DIR"
            exit 1
        fi
        
        # Make autogen.sh executable
        chmod +x autogen.sh
        
        # Check for required tools
        if ! command -v autoconf &> /dev/null; then
            echo "⚠️  Warning: autoconf not found. Install with: brew install autoconf"
        fi
        if ! command -v automake &> /dev/null; then
            echo "⚠️  Warning: automake not found. Install with: brew install automake"
        fi
        if ! command -v libtool &> /dev/null; then
            echo "⚠️  Warning: libtool not found. Install with: brew install libtool"
        fi
        
        # Run autogen.sh
        ./autogen.sh || {
            echo "❌ Failed to generate configure script"
            echo "💡 Make sure you have autotools installed: brew install autoconf automake libtool"
            exit 1
        }
        
        # Verify configure was created
        if [ ! -f "configure" ]; then
            echo "❌ configure script was not created after running autogen.sh"
            echo "💡 Check the output above for errors."
            exit 1
        fi
        
        # Make configure executable
        chmod +x configure
    fi
    
    # Common configuration
    COMMON_FLAGS="--enable-module-recovery --disable-tests --disable-benchmark --disable-exhaustive-tests"
    
    if [ ! -f "$SECP256K1_DIR/build/macos/lib/libsecp256k1.dylib" ]; then
        echo "🍎 Building for macOS..."
        ./configure $COMMON_FLAGS --prefix="$SECP256K1_DIR/build/macos"
        make clean > /dev/null 2>&1
        make -j$(sysctl -n hw.ncpu)
        make install
        echo "✓ macOS library built"
    else
        echo "✓ macOS library already exists"
    fi
    
    cd "$SCRIPT_DIR"
    echo ""
else
    echo "⏭️  Skipping native library build"
    echo ""
fi

# Navigate to Flutter project
cd "$NAVIGATE_DIR"

# Create release directory
mkdir -p "$RELEASE_DIR"

echo "🍎 Building macOS release..."
flutter build macos --release

# Copy library to app bundle (required for macOS apps)
LIB_SOURCE="$SECP256K1_DIR/build/macos/lib/libsecp256k1.dylib"
APP_FRAMEWORKS="$NAVIGATE_DIR/build/macos/Build/Products/Release/navigate.app/Contents/Frameworks"

[ ! -f "$LIB_SOURCE" ] && { echo "❌ Error: Library not found at $LIB_SOURCE"; exit 1; }

mkdir -p "$APP_FRAMEWORKS"
cp "$LIB_SOURCE" "$APP_FRAMEWORKS/" && \
install_name_tool -id "@executable_path/../Frameworks/libsecp256k1.dylib" "$APP_FRAMEWORKS/libsecp256k1.dylib" 2>/dev/null

# Copy to release directory
RELEASE_PLATFORM_DIR="$RELEASE_DIR/macos"
rm -rf "$RELEASE_PLATFORM_DIR"
mkdir -p "$RELEASE_PLATFORM_DIR"
cp -R "$NAVIGATE_DIR/build/macos/Build/Products/Release/navigate.app" "$RELEASE_PLATFORM_DIR/"

echo "✓ macOS release built"
echo "  Location: $RELEASE_PLATFORM_DIR/navigate.app"

echo ""
echo "✅ Release build complete!"
echo ""
echo "📦 Release files are in: $RELEASE_DIR/macos"
echo ""

