# DuckStation Regression Tester Scripts

Scripts for building and using the DuckStation regression tester (`duckstation-regtest`).

## Building

### macOS (Apple Silicon)

```bash
./build-regtest.sh [BIOS_DIR]
```

**Arguments:**
- `BIOS_DIR` (optional): Path to your PS1 BIOS directory. Defaults to `~/workspace/ps/ps-bios`. Can also be set via `DUCKSTATION_BIOS_DIR` environment variable.

**Prerequisites:**
- Xcode (full installation from App Store)
- Homebrew

After installing Xcode, run:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -downloadComponent MetalToolchain
```

The built binary will be at: `build/bin/duckstation-regtest`

## Usage

### Basic Usage

```bash
# Set BIOS directory (required)
export DUCKSTATION_BIOS_DIR="/path/to/your/bios"

# Run a game for 300 frames
./build/bin/duckstation-regtest -console -frames 300 /path/to/game.cue
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-console` | Enable console logging |
| `-frames <N>` | Run for N frames then exit |
| `-renderer <type>` | Set renderer: `Software`, `Vulkan`, `OpenGL`, `Metal` |
| `-dumpdir <dir>` | Directory to save frame dumps |
| `-dumpinterval <N>` | Save a screenshot every N frames |
| `-upscale <mult>` | Resolution multiplier (e.g., 2 for 2x) |
| `-pgxp` | Enable PGXP geometry correction |

### Examples

**Run for 5 seconds (300 frames at 60fps):**
```bash
./build/bin/duckstation-regtest -console -frames 300 game.cue
```

**Capture screenshots every 60 frames:**
```bash
./build/bin/duckstation-regtest -console -frames 1000 \
  -dumpdir ./screenshots -dumpinterval 60 game.cue
```

**Use software renderer at 2x resolution:**
```bash
./build/bin/duckstation-regtest -console -frames 500 \
  -renderer Software -upscale 2 game.cue
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DUCKSTATION_BIOS_DIR` | Path to PS1 BIOS directory (required) |

## BIOS Files

You need PS1 BIOS files to run games. Place them in your BIOS directory:
- NTSC-U (US): `scph1001.bin`, `scph5501.bin`, `scph7001.bin`
- PAL (Europe): `scph5502.bin`, `scph7502.bin`
- NTSC-J (Japan): `scph5500.bin`

The emulator will auto-detect the appropriate BIOS based on the game region.

