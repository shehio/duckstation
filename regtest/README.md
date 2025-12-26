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
| `-input <inputs>` | Schedule button inputs at specific frames (see below) |

### Input Injection

The `-input` option allows you to schedule button presses at specific frames for automated testing and input replay.

**Format:** `frame:button,frame:button:release,...`

**Supported buttons:** `cross`/`x`, `circle`, `square`, `triangle`, `start`, `select`, `up`, `down`, `left`, `right`, `l1`, `l2`, `l3`, `r1`, `r2`, `r3`

**Example:**
```bash
./build/bin/duckstation-regtest -console -frames 500 \
  -input "100:start,200:start:release,300:cross" game.cue
```

This will:
- Press Start at frame 100
- Release Start at frame 200
- Press Cross at frame 300

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

**Automate menu navigation (press Start, wait, press Cross):**
```bash
./build/bin/duckstation-regtest -console -frames 1000 \
  -input "300:start,350:start:release,500:cross,550:cross:release" game.cue
```

**Run Crash Bandicoot 3 test (skip intros, jump & spin in Warp Room):**
```bash
INPUT=$(grep -v '^#' regtest/crash3_warp_room_test.txt | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
./build/bin/duckstation-regtest -console -frames 4000 \
  -dumpdir /tmp/crash_test -dumpinterval 25 \
  -input "$INPUT" /path/to/Crash\ Bandicoot\ 3.cue
```

## Input File Format

You can store inputs in a text file for easier editing. See `crash3_warp_room_test.txt` for an example.

**Format:**
```
# Comments start with #
frame:button
frame:button:release
```

**Action Durations (at 50fps PAL):**
- Button tap: ~40-50 frames (hold for ~1 second)
- Jump animation: ~60 frames (~1.2 seconds)
- Spin animation: ~40 frames (~0.8 seconds)
- Menu transition: ~300 frames (~6 seconds)

**To convert file to command-line format:**
```bash
INPUT=$(grep -v '^#' input_file.txt | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
./build/bin/duckstation-regtest -input "$INPUT" game.cue
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

