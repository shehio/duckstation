#!/bin/bash
# DuckStation Regression Tester Build Script for macOS (Apple Silicon)
# This script builds the duckstation-regtest binary from source with input injection support
#
# Usage:
#   ./build-regtest.sh [BIOS_DIR]
#
#   BIOS_DIR: Optional path to BIOS directory (default: ~/workspace/ps/ps-bios)
#             Can also be set via DUCKSTATION_BIOS_DIR environment variable
#
# Prerequisites:
#   - Xcode (full installation from App Store, not just command line tools)
#   - Homebrew (https://brew.sh)
#
# After installing Xcode, run:
#   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#   sudo xcodebuild -license accept
#   xcodebuild -downloadComponent MetalToolchain

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_LOCAL="${SCRIPT_DIR}/deps-local"
BUILD_DIR="${SCRIPT_DIR}/build"
TMP_DIR="/tmp/duckstation-deps-build"

# BIOS directory: use command line arg, env var, or default
if [ -n "$1" ]; then
  BIOS_DIR="$1"
elif [ -n "$DUCKSTATION_BIOS_DIR" ]; then
  BIOS_DIR="$DUCKSTATION_BIOS_DIR"
else
  BIOS_DIR="${HOME}/workspace/ps/ps-bios"
fi

# Version commits (from scripts/deps/versions)
CPUINFO_COMMIT="ad0339d52555e0252688c4cba69695e13bf3e383"
PLUTOSVG_COMMIT="bc845bb6b6511e392f9e1097b26f70cf0b3c33be"
DISCORD_RPC_COMMIT="cc59d26d1d628fbd6527aac0ac1d6301f4978b92"
SOUNDTOUCH_COMMIT="463ade388f3a51da078dc9ed062bf28e4ba29da7"
SHADERC_COMMIT="85cd26cc38e3e8b5e3c649f4551900ee330d6552"
SPIRV_CROSS_TAG="vulkan-sdk-1.4.328.1"
LIBPNG_VERSION="1.6.50"

echo "=== DuckStation Regression Tester Build Script ==="
echo "Script directory: ${SCRIPT_DIR}"
echo "BIOS directory: ${BIOS_DIR}"
echo ""

# Check for Xcode
if ! xcode-select -p | grep -q "Xcode.app"; then
    echo "ERROR: Full Xcode installation required (not just command line tools)"
    echo "Please install Xcode from the App Store, then run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "  sudo xcodebuild -license accept"
    echo "  xcodebuild -runFirstLaunch"
    echo "  xcodebuild -downloadComponent MetalToolchain"
    exit 1
fi

# Check for Metal compiler
if ! xcrun --find metal &>/dev/null; then
    echo "ERROR: Metal compiler not found. Please run:"
    echo "  xcodebuild -downloadComponent MetalToolchain"
    exit 1
fi

echo "=== Step 1: Installing Homebrew Dependencies ==="
brew install cmake ninja qt@6 sdl3 zstd pkg-config shaderc spirv-cross sound-touch libzip ffmpeg freetype harfbuzz webp jpeg-turbo || true

echo ""
echo "=== Step 2: Creating Local Dependencies Directory ==="
mkdir -p "${DEPS_LOCAL}/lib/cmake"
mkdir -p "${DEPS_LOCAL}/include"
mkdir -p "${TMP_DIR}"

echo ""
echo "=== Step 3: Building cpuinfo ==="
cd "${TMP_DIR}"
if [ ! -f "cpuinfo-done" ]; then
    curl -sL "https://github.com/pytorch/cpuinfo/archive/${CPUINFO_COMMIT}.tar.gz" -o cpuinfo.tar.gz
    tar xzf cpuinfo.tar.gz
    cd "cpuinfo-${CPUINFO_COMMIT}"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_LOCAL}" \
        -DCPUINFO_BUILD_BENCHMARKS=OFF \
        -DCPUINFO_BUILD_UNIT_TESTS=OFF \
        -DCPUINFO_BUILD_MOCK_TESTS=OFF \
        -DCPUINFO_BUILD_PKG_CONFIG=ON
    cmake --build build -j$(sysctl -n hw.ncpu)
    cmake --install build
    touch "${TMP_DIR}/cpuinfo-done"
    echo "cpuinfo built successfully"
else
    echo "cpuinfo already built, skipping"
fi

echo ""
echo "=== Step 4: Building plutosvg ==="
cd "${TMP_DIR}"
if [ ! -f "plutosvg-done" ]; then
    curl -sL "https://github.com/stenzek/plutosvg/archive/${PLUTOSVG_COMMIT}.tar.gz" -o plutosvg.tar.gz
    tar xzf plutosvg.tar.gz
    cd "plutosvg-${PLUTOSVG_COMMIT}"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_LOCAL}" \
        -DPLUTOSVG_BUILD_EXAMPLES=OFF
    cmake --build build -j$(sysctl -n hw.ncpu)
    cmake --install build
    touch "${TMP_DIR}/plutosvg-done"
    echo "plutosvg built successfully"
else
    echo "plutosvg already built, skipping"
fi

echo ""
echo "=== Step 5: Building discord-rpc ==="
cd "${TMP_DIR}"
if [ ! -f "discord-rpc-done" ]; then
    curl -sL "https://github.com/stenzek/discord-rpc/archive/${DISCORD_RPC_COMMIT}.tar.gz" -o discord-rpc.tar.gz
    tar xzf discord-rpc.tar.gz
    cd "discord-rpc-${DISCORD_RPC_COMMIT}"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_LOCAL}"
    cmake --build build -j$(sysctl -n hw.ncpu)
    cmake --install build
    touch "${TMP_DIR}/discord-rpc-done"
    echo "discord-rpc built successfully"
else
    echo "discord-rpc already built, skipping"
fi

echo ""
echo "=== Step 6: Building soundtouch ==="
cd "${TMP_DIR}"
if [ ! -f "soundtouch-done" ]; then
    curl -sL "https://github.com/stenzek/soundtouch/archive/${SOUNDTOUCH_COMMIT}.tar.gz" -o soundtouch.tar.gz
    tar xzf soundtouch.tar.gz
    cd "soundtouch-${SOUNDTOUCH_COMMIT}"
    cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${DEPS_LOCAL}"
    cmake --build build -j$(sysctl -n hw.ncpu)
    cmake --install build
    touch "${TMP_DIR}/soundtouch-done"
    echo "soundtouch built successfully"
else
    echo "soundtouch already built, skipping"
fi

echo ""
echo "=== Step 7: Downloading Pre-built Release for Additional Libraries ==="
cd "${SCRIPT_DIR}"
if [ ! -d "DuckStation.app" ]; then
    echo "Downloading pre-built release..."
    gh release download latest --pattern "duckstation-mac-release.zip" -D . --clobber || {
        echo "Failed to download with gh, trying curl..."
        curl -sL "https://github.com/stenzek/duckstation/releases/download/latest/duckstation-mac-release.zip" -o duckstation-mac-release.zip
    }
    unzip -o duckstation-mac-release.zip
fi

echo ""
echo "=== Step 8: Copying Libraries from Pre-built Release ==="
# Copy dylibs that are difficult to build
cp "${SCRIPT_DIR}/DuckStation.app/Contents/Frameworks/libharfbuzz.dylib" "${DEPS_LOCAL}/lib/"
cp "${SCRIPT_DIR}/DuckStation.app/Contents/Frameworks/libshaderc_ds.dylib" "${DEPS_LOCAL}/lib/"
cp "${SCRIPT_DIR}/DuckStation.app/Contents/Frameworks/libspirv-cross-c-shared.0.dylib" "${DEPS_LOCAL}/lib/"
cp "${SCRIPT_DIR}/DuckStation.app/Contents/Frameworks/libpng16.16.dylib" "${DEPS_LOCAL}/lib/"
ln -sf libpng16.16.dylib "${DEPS_LOCAL}/lib/libpng16.dylib"
ln -sf libpng16.16.dylib "${DEPS_LOCAL}/lib/libpng.dylib"
echo "Libraries copied"

echo ""
echo "=== Step 9: Creating CMake Config Files ==="

# harfbuzz config
mkdir -p "${DEPS_LOCAL}/lib/cmake/harfbuzz"
cat > "${DEPS_LOCAL}/lib/cmake/harfbuzz/harfbuzz-config.cmake" << EOF
# harfbuzz CMake Config
if(NOT TARGET harfbuzz::harfbuzz)
  add_library(harfbuzz::harfbuzz SHARED IMPORTED)
  set_target_properties(harfbuzz::harfbuzz PROPERTIES
    IMPORTED_LOCATION "${DEPS_LOCAL}/lib/libharfbuzz.dylib"
    IMPORTED_LOCATION_RELEASE "${DEPS_LOCAL}/lib/libharfbuzz.dylib"
    INTERFACE_INCLUDE_DIRECTORIES "${DEPS_LOCAL}/include"
  )
endif()
EOF

# Shaderc config
mkdir -p "${DEPS_LOCAL}/lib/cmake/Shaderc"
cat > "${DEPS_LOCAL}/lib/cmake/Shaderc/ShadercConfig.cmake" << EOF
# Shaderc CMake Config
if(NOT TARGET Shaderc::shaderc_shared)
  add_library(Shaderc::shaderc_shared SHARED IMPORTED)
  set_target_properties(Shaderc::shaderc_shared PROPERTIES
    IMPORTED_LOCATION "${DEPS_LOCAL}/lib/libshaderc_ds.dylib"
    IMPORTED_LOCATION_RELEASE "${DEPS_LOCAL}/lib/libshaderc_ds.dylib"
    INTERFACE_INCLUDE_DIRECTORIES "${DEPS_LOCAL}/include"
  )
endif()
EOF

# spirv-cross config
mkdir -p "${DEPS_LOCAL}/lib/cmake/spirv_cross_c_shared"
cat > "${DEPS_LOCAL}/lib/cmake/spirv_cross_c_shared/spirv_cross_c_sharedConfig.cmake" << EOF
# spirv-cross-c-shared CMake Config
if(NOT TARGET spirv-cross-c-shared)
  add_library(spirv-cross-c-shared SHARED IMPORTED)
  set_target_properties(spirv-cross-c-shared PROPERTIES
    IMPORTED_LOCATION "${DEPS_LOCAL}/lib/libspirv-cross-c-shared.0.dylib"
    IMPORTED_LOCATION_RELEASE "${DEPS_LOCAL}/lib/libspirv-cross-c-shared.0.dylib"
    IMPORTED_SONAME_RELEASE "${DEPS_LOCAL}/lib/libspirv-cross-c-shared.0.dylib"
    INTERFACE_INCLUDE_DIRECTORIES "${DEPS_LOCAL}/include"
  )
endif()
EOF

# PNG config (with APNG support)
mkdir -p "${DEPS_LOCAL}/lib/cmake/PNG"
cat > "${DEPS_LOCAL}/lib/cmake/PNG/PNGConfig.cmake" << EOF
# PNG CMake Config with APNG support
set(PNG_FOUND TRUE)
set(PNG_INCLUDE_DIRS "${DEPS_LOCAL}/include")
set(PNG_LIBRARIES "${DEPS_LOCAL}/lib/libpng16.dylib")
set(PNG_VERSION "1.6.50")

if(NOT TARGET PNG::PNG)
  add_library(PNG::PNG SHARED IMPORTED)
  set_target_properties(PNG::PNG PROPERTIES
    IMPORTED_LOCATION "${DEPS_LOCAL}/lib/libpng16.16.dylib"
    INTERFACE_INCLUDE_DIRECTORIES "${DEPS_LOCAL}/include"
    INTERFACE_LINK_LIBRARIES "ZLIB::ZLIB"
  )
endif()
EOF

cat > "${DEPS_LOCAL}/lib/cmake/PNG/PNGConfigVersion.cmake" << 'EOF'
set(PACKAGE_VERSION "1.6.50")
if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_FIND_VERSION STREQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF

echo "CMake configs created"

echo ""
echo "=== Step 10: Downloading Headers ==="

# Shaderc headers
mkdir -p "${DEPS_LOCAL}/include/shaderc"
curl -sL "https://raw.githubusercontent.com/stenzek/shaderc/${SHADERC_COMMIT}/libshaderc/include/shaderc/shaderc.h" \
    -o "${DEPS_LOCAL}/include/shaderc/shaderc.h"
curl -sL "https://raw.githubusercontent.com/stenzek/shaderc/${SHADERC_COMMIT}/libshaderc/include/shaderc/env.h" \
    -o "${DEPS_LOCAL}/include/shaderc/env.h"
curl -sL "https://raw.githubusercontent.com/stenzek/shaderc/${SHADERC_COMMIT}/libshaderc/include/shaderc/status.h" \
    -o "${DEPS_LOCAL}/include/shaderc/status.h"
curl -sL "https://raw.githubusercontent.com/stenzek/shaderc/${SHADERC_COMMIT}/libshaderc/include/shaderc/visibility.h" \
    -o "${DEPS_LOCAL}/include/shaderc/visibility.h"

# SPIRV-Cross header
curl -sL "https://raw.githubusercontent.com/KhronosGroup/SPIRV-Cross/${SPIRV_CROSS_TAG}/spirv_cross_c.h" \
    -o "${DEPS_LOCAL}/include/spirv_cross_c.h"

# SPIRV header
curl -sL "https://raw.githubusercontent.com/KhronosGroup/SPIRV-Headers/${SPIRV_CROSS_TAG}/include/spirv/unified1/spirv.h" \
    -o "${DEPS_LOCAL}/include/spirv.h"

echo "Headers downloaded"

echo ""
echo "=== Step 11: Downloading and Patching libpng Headers (APNG support) ==="
cd "${TMP_DIR}"
if [ ! -f "libpng-headers-done" ]; then
    curl -sL "https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz" -o libpng.tar.gz
    tar xzf libpng.tar.gz
    cd "libpng-${LIBPNG_VERSION}"
    patch -p1 < "${SCRIPT_DIR}/scripts/deps/libpng-1.6.50-apng.patch"
    cp png.h pngconf.h "${DEPS_LOCAL}/include/"
    cp scripts/pnglibconf.h.prebuilt "${DEPS_LOCAL}/include/pnglibconf.h"
    touch "${TMP_DIR}/libpng-headers-done"
    echo "libpng headers installed"
else
    echo "libpng headers already installed, skipping"
fi

echo ""
echo "=== Step 12: Configuring CMake ==="
cd "${SCRIPT_DIR}"
rm -rf "${BUILD_DIR}"
cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -GNinja \
    -DBUILD_QT_FRONTEND=OFF \
    -DBUILD_REGTEST=ON \
    -DENABLE_VULKAN=OFF \
    -DENABLE_OPENGL=OFF \
    -DCMAKE_PREFIX_PATH="${DEPS_LOCAL};/opt/homebrew"

echo ""
echo "=== Step 13: Building duckstation-regtest ==="
# Export BIOS directory for the build/runtime
export DUCKSTATION_BIOS_DIR="${BIOS_DIR}"
ninja -C "${BUILD_DIR}" duckstation-regtest

echo ""
echo "=== Step 14: Setting up Runtime Environment ==="
# Copy dylibs to Frameworks folder (expected by the binary)
mkdir -p "${BUILD_DIR}/Frameworks"
cp "${DEPS_LOCAL}/lib/"*.dylib "${BUILD_DIR}/Frameworks/"

# Copy resources
mkdir -p "${BUILD_DIR}/bin/resources"
cp -r "${SCRIPT_DIR}/DuckStation.app/Contents/Resources/"* "${BUILD_DIR}/bin/resources/"

# Copy metallib files alongside binary (NSBundle mainBundle looks there for CLI tools)
cp "${BUILD_DIR}/src/duckstation-regtest/"*.metallib "${BUILD_DIR}/bin/"

echo ""
echo "=== Build Complete! ==="
echo ""
echo "The regression tester binary is at:"
echo "  ${BUILD_DIR}/bin/duckstation-regtest"
echo ""
echo "Usage example:"
echo "  ${BUILD_DIR}/bin/duckstation-regtest -console -frames 300 /path/to/game.cue"
echo ""
echo "Options:"
echo "  -console           Enable console logging"
echo "  -frames <N>        Run for N frames then exit"
echo "  -renderer <type>   Set renderer (Software, Vulkan, OpenGL, Metal)"
echo "  -dumpdir <dir>     Directory to dump frames"
echo "  -dumpinterval <N>  Dump every N frames"
echo "  -upscale <mult>    Resolution multiplier"
echo "  -pgxp              Enable PGXP"
echo "  -input <inputs>    Schedule button inputs at specific frames"
echo "                     Format: \"frame:button,frame:button:release,...\""
echo "                     Buttons: cross/x, circle, square, triangle, start, select,"
echo "                              up, down, left, right, l1, l2, l3, r1, r2, r3"
echo "                     Example: -input \"3000:start,3100:start:release,3500:cross\""
echo ""
echo "NOTE: You need a PS1 BIOS file in:"
echo "  ${BIOS_DIR}/"
echo ""
echo "To use a different BIOS directory, either:"
echo "  1. Pass it as an argument: ./build-regtest.sh /path/to/bios"
echo "  2. Set environment variable: DUCKSTATION_BIOS_DIR=/path/to/bios ./build-regtest.sh"
echo "  3. Set it at runtime: DUCKSTATION_BIOS_DIR=/path/to/bios ${BUILD_DIR}/bin/duckstation-regtest ..."
echo ""
