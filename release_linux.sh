#!/bin/bash

# Navigate - Linux Release Build Script
# Builds release versions of the app for distribution on Linux
# Usage: ./release_linux.sh [--skip-build]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_BUILD=false
RELEASE_DIR="$SCRIPT_DIR/release"
NAVIGATE_DIR="$SCRIPT_DIR/navigate"
PLATFORM="linux"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: ./release_linux.sh [--skip-build]"
            exit 1
            ;;
    esac
done

echo "📦 Navigate Release Build (Linux)"
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

# Check for Linux build dependencies
if [ "$SKIP_BUILD" = false ]; then
    MISSING_DEPS=()
    
    # Check for autoconf
    if ! command -v autoconf &> /dev/null && [ ! -f /usr/bin/autoconf ]; then
        MISSING_DEPS+=("autoconf")
    fi
    
    # Check for automake
    if ! command -v automake &> /dev/null && [ ! -f /usr/bin/automake ]; then
        MISSING_DEPS+=("automake")
    fi
    
    # Check for libtool (can be in different locations or provided by libtool-bin)
    # Note: libtool might be installed but not in PATH, so we check multiple ways
    LIBTOOL_FOUND=false
    if command -v libtool &> /dev/null; then
        LIBTOOL_FOUND=true
    elif [ -f /usr/bin/libtool ] || [ -f /usr/local/bin/libtool ]; then
        LIBTOOL_FOUND=true
    elif command -v libtoolize &> /dev/null; then
        # libtoolize is often provided by libtool package
        LIBTOOL_FOUND=true
    elif command -v dpkg &> /dev/null; then
        # Check if libtool package is installed (even if not in PATH)
        # dpkg -l output format: ii  package-name  version  description
        if dpkg -l 2>/dev/null | grep -q "^ii.*libtool"; then
            LIBTOOL_FOUND=true
        fi
    fi
    
    if [ "$LIBTOOL_FOUND" = false ]; then
        # Don't fail on libtool - autogen.sh will handle it
        # Just warn and let the build process show the actual error
        echo "⚠️  Warning: libtool not found in PATH"
        echo "   If autogen.sh fails, install with: sudo apt-get install libtool"
        echo ""
    fi
    
    # Check for make
    if ! command -v make &> /dev/null && [ ! -f /usr/bin/make ]; then
        MISSING_DEPS+=("build-essential")
    fi
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "❌ Missing required build dependencies for Linux:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "   - $dep"
        done
        echo ""
        echo "💡 Please install them with:"
        echo "   sudo apt-get update"
        echo "   sudo apt-get install -y ${MISSING_DEPS[*]}"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
fi

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
        
        # Run autogen.sh
        ./autogen.sh || {
            echo "❌ Failed to generate configure script"
            echo "💡 Make sure you have autotools installed: sudo apt-get install autoconf automake libtool"
            exit 1
        }
        
        # Verify configure was created
        if [ ! -f "configure" ]; then
            echo "❌ configure script was not created after running autogen.sh"
            echo "💡 Check the output above for errors. You may need to install autotools."
            exit 1
        fi
        
        # Make configure executable
        chmod +x configure
    fi
    
    # Common configuration
    COMMON_FLAGS="--enable-module-recovery --disable-tests --disable-benchmark --disable-exhaustive-tests"
    
    if [ ! -f "$SECP256K1_DIR/build/linux/lib/libsecp256k1.so" ]; then
        echo "🐧 Building for Linux..."
        ./configure $COMMON_FLAGS --prefix="$SECP256K1_DIR/build/linux"
        make clean > /dev/null 2>&1
        make -j$(nproc)
        make install
        echo "✓ Linux library built"
    else
        echo "✓ Linux library already exists"
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

echo "🐧 Building Linux release..."
flutter build linux --release

LINUX_BUNDLE="$NAVIGATE_DIR/build/linux/x64/release/bundle"

if [ ! -d "$LINUX_BUNDLE" ]; then
    echo "❌ Error: Linux bundle not found at $LINUX_BUNDLE"
    exit 1
fi

# Copy to release directory
RELEASE_PLATFORM_DIR="$RELEASE_DIR/linux"
rm -rf "$RELEASE_PLATFORM_DIR"
mkdir -p "$RELEASE_PLATFORM_DIR"
cp -R "$LINUX_BUNDLE"/* "$RELEASE_PLATFORM_DIR/"

echo "✓ Linux release built"
echo "  Location: $RELEASE_PLATFORM_DIR/"

echo ""
echo "✅ Release build complete!"
echo ""
echo "📦 Release files are in: $RELEASE_DIR/linux"
echo ""

