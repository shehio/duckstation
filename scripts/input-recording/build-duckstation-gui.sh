#!/bin/bash
# Build DuckStation GUI with Input Recording support
# ==================================================
#
# This script builds the full DuckStation GUI application with input recording.
#
# IMPORTANT: The DuckStation project requires Qt 6.10.1+ which is newer than
# what's available via Homebrew (6.9.3). You have two options:
#
# Option 1: Use the official DuckStation release (recommended)
#   - Download from: https://github.com/stenzek/duckstation/releases
#   - Note: This won't have the custom input recording feature
#
# Option 2: Build Qt 6.10.1 from source (advanced)
#   - Download Qt 6.10.1 from qt.io
#   - Build and install to deps-local/
#   - Then run this script
#
# Option 3: Use the regtest binary for headless input replay
#   - The regtest binary works with system libraries
#   - See regtest/README.md for usage
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "=== DuckStation GUI Build Script ==="
echo ""

# Check for Qt
QT_VERSION=$(brew list --versions qt@6 2>/dev/null | awk '{print $2}' || echo "not installed")
echo "System Qt version: $QT_VERSION"
echo "Required Qt version: 6.10.1+"
echo ""

if [[ "$QT_VERSION" < "6.10" ]]; then
    echo "ERROR: Qt 6.10.1+ is required but $QT_VERSION is installed."
    echo ""
    echo "Options:"
    echo "  1. Download official DuckStation release (no input recording)"
    echo "  2. Build Qt 6.10.1 from source and install to deps-local/"
    echo "  3. Use duckstation-regtest for headless input replay"
    echo ""
    echo "For option 3, build regtest with:"
    echo "  cd $PROJECT_ROOT/regtest && ./build-regtest.sh"
    exit 1
fi

# Check for deps-local Qt
if [ ! -d "deps-local/lib/QtCore.framework" ]; then
    echo "ERROR: Qt not found in deps-local/"
    echo "The project requires a patched Qt build in deps-local/"
    echo ""
    echo "See: https://github.com/stenzek/duckstation/wiki/Building"
    exit 1
fi

echo "Building DuckStation GUI..."
mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_QT_FRONTEND=ON \
    -G Ninja

ninja

echo ""
echo "=== Build Complete ==="
echo "App location: $PROJECT_ROOT/build/bin/DuckStation.app"
echo ""
echo "To run:"
echo "  open $PROJECT_ROOT/build/bin/DuckStation.app"

