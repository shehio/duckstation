#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPS_DIR="$PROJECT_ROOT/deps"

cd "$PROJECT_ROOT"

# Build dependencies if not already built
if [ ! -d "$DEPS_DIR/lib/cmake/Qt6" ]; then
    echo "=== Building Dependencies ==="
    echo "This will take 1-2 hours the first time..."
    echo ""
    "$PROJECT_ROOT/scripts/deps/build-dependencies-mac.sh" "$DEPS_DIR"
fi

# Verify deps exist
if [ ! -d "$DEPS_DIR/lib/cmake/Qt6" ]; then
    echo "ERROR: Dependencies not found in $DEPS_DIR"
    echo "The dependency build may have failed."
    exit 1
fi

echo ""
echo "=== Building DuckStation Regtest ==="
mkdir -p build-regtest
cd build-regtest

cmake "$PROJECT_ROOT" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DCMAKE_PREFIX_PATH="$DEPS_DIR" \
  -DBUILD_QT_FRONTEND=OFF \
  -DBUILD_REGTEST=ON \
  -DENABLE_OPENGL=OFF

cmake --build . --parallel --target duckstation-regtest

echo ""
echo "=== Build Complete ==="
echo "Binary location: $PROJECT_ROOT/build-regtest/bin/duckstation-regtest"
echo ""
echo "Usage:"
echo "  $PROJECT_ROOT/build-regtest/bin/duckstation-regtest -console -frames 300 /path/to/game.cue"
echo ""
echo "Options:"
echo "  -console           Enable console logging"
echo "  -frames <N>        Run for N frames then exit"
echo "  -renderer <type>   Set renderer (Software, Vulkan, OpenGL, Metal)"
echo "  -input <inputs>    Schedule inputs (e.g. \"3000:start,3500:cross\")"
