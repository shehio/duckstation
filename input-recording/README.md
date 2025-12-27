# Input Recording

Record your controller inputs while playing games in DuckStation, then replay them for automated testing or AI training data collection.

## Overview

Input recording captures every button press and release with the exact frame number, allowing you to:
- **Replay gameplay** headlessly with `duckstation-regtest`
- **Create training data** for AI/ML models (behavioral cloning)
- **Automate testing** by recording once, replaying many times
- **Share input sequences** with others
- **Capture screenshots** at preset intervals during recording
- **Dump RAM** to analyze game state (lives, score, position, etc.)

## Building DuckStation with Input Recording

The input recording feature requires building DuckStation from source. 

### ⚠️ Qt Version Requirement

**Important:** DuckStation requires Qt 6.10.1+ which is newer than what's available via Homebrew (6.9.3 as of Dec 2024). 

**Options:**

1. **Use the regtest binary** (Recommended for headless replay)
   - Build with: `cd regtest && ./build-regtest.sh`
   - Works with system libraries, no Qt needed
   - See `regtest/README.md` for usage

2. **Download official DuckStation release**
   - Get from: https://github.com/stenzek/duckstation/releases
   - Note: Won't have custom input recording feature

3. **Build Qt 6.10.1 from source** (Advanced)
   - Download from qt.io
   - Build and install to `deps-local/`
   - Then build DuckStation

### macOS (Apple Silicon) - If Qt 6.10.1+ Available

```bash
cd /path/to/duckstation

# Build script (checks Qt version)
./scripts/input-recording/build-duckstation-gui.sh

# Or manually:
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_QT_FRONTEND=ON -G Ninja
ninja

# The app will be at: build/bin/DuckStation.app
```

## How to Record Inputs

### Step 1: Configure Hotkeys

1. Open **DuckStation** (GUI app)
2. Go to **Settings → Hotkeys → System**
3. Bind keys for:
   - **Toggle Input Recording** → e.g., `F5` (basic recording)
   - **Toggle Input Recording with Screenshots** → e.g., `F7` (captures screenshots every 60 frames + RAM dump on save)
   - **Toggle Full Input Recording** → e.g., `F8` (screenshots + RAM dumps every 60 frames)
   - **Save Input Recording** → e.g., `F6`

### Step 2: Record Your Gameplay

1. **Load a game** in DuckStation
2. **Navigate to the section** you want to record (e.g., main menu, start of a level)
3. **Press F5** (or your bound key) to start recording
   - You'll see: "Input recording started"
4. **Play the game** - all your inputs are being recorded
5. **Press F5** again to stop recording
   - You'll see: "Input recording stopped. X inputs recorded."
6. **Press F6** to save the recording
   - Saved to: `~/Library/Application Support/DuckStation/input_recording_XXXXX.txt`

### Step 3: Find Your Recording

The recording is saved in your DuckStation data folder:

```bash
# macOS
ls ~/Library/Application\ Support/DuckStation/input_recording_*.txt

# Linux
ls ~/.local/share/duckstation/input_recording_*.txt

# Windows
dir %APPDATA%\DuckStation\input_recording_*.txt
```

## Recording Modes

### Basic Recording (Toggle Input Recording)
- Records only button inputs
- Lightweight, minimal disk usage
- Output: `input_recording_XXXXX.txt`

### Recording with Screenshots (Toggle Input Recording with Screenshots)
- Records button inputs
- Captures screenshots every 60 frames (~1 second)
- Dumps full RAM when you save
- Output directory: `input_recording_TIMESTAMP/`
  - `input_recording_XXXXX.txt` - inputs
  - `frame_00000XXX.png` - screenshots
  - `input_recording_XXXXX.ram.bin` - 2MB RAM dump

### Full Recording (Toggle Full Input Recording)
- Records button inputs
- Captures screenshots every 60 frames
- Dumps RAM every 60 frames (for state analysis)
- Output directory: `input_recording_TIMESTAMP/`
  - `input_recording_XXXXX.txt` - inputs
  - `frame_00000XXX.png` - screenshots
  - `ram_00000XXX.bin` - RAM dump per interval

## RAM Dumps

RAM dumps capture the full 2MB PlayStation memory, which contains:
- **Game variables**: lives, health, score, position
- **Object states**: enemy positions, collectibles
- **Level data**: current level, progress

### Analyzing RAM Dumps

#### Using the Python Script (Recommended)

We provide a Python script for easy RAM analysis:

```bash
cd ~/Library/Application\ Support/DuckStation/input_recording_*/

# Basic info about a dump
python3 scripts/input-recording/read_ram_dump.py ram_00012034.bin

# Read known Crash 3 addresses (lives, wumpa, crystals)
python3 scripts/input-recording/read_ram_dump.py ram_00012034.bin --game crash3

# Read a specific memory address
python3 scripts/input-recording/read_ram_dump.py ram_00012034.bin --address 0x80068F58 --size 1

# Show hex dump at an address
python3 scripts/input-recording/read_ram_dump.py ram_00012034.bin --address 0x80068F58 --hex

# Compare two dumps to find what changed (great for finding addresses!)
python3 scripts/input-recording/read_ram_dump.py ram_00012034.bin ram_00014854.bin --diff
```

#### Using Command Line (xxd)

```bash
# View first 50 lines as hex
xxd ram_00001000.bin | head -50

# Read at specific offset (0x68F58 = address 0x80068F58)
xxd -s 0x68F58 -l 16 ram_00012034.bin

# Compare two dumps
diff <(xxd ram_00001000.bin) <(xxd ram_00002000.bin) | head -50
```

### Finding Game-Specific Memory Addresses

To find addresses for lives, score, position, etc.:

1. **Record RAM at frame X** (e.g., when you have 3 lives)
2. **Change the value in-game** (e.g., lose a life → 2 lives)
3. **Record RAM at frame Y**
4. **Compare the dumps:**
   ```bash
   python3 read_ram_dump.py ram_frameX.bin ram_frameY.bin --diff
   ```
5. **Look for addresses that changed from 3 → 2**

### Common Memory Addresses (Crash Bandicoot 3)

| Address | Size | Description |
|---------|------|-------------|
| `0x80068F58` | 1 byte | Lives |
| `0x80068F5C` | 2 bytes | Wumpa fruits |
| `0x80068F60` | 4 bytes | Crystals collected |

*Note: Addresses vary by game and region. Use the diff method above to find them.*

## Recording Format

The recording is saved in a simple text format compatible with `duckstation-regtest`:

```
100:start,150:start:release,300:cross,350:cross:release,500:square,550:square:release
```

Each entry is `frame:button` or `frame:button:release`:
- `100:start` = Press Start at frame 100
- `150:start:release` = Release Start at frame 150

### Supported Buttons

| Button | Description |
|--------|-------------|
| `cross` / `x` | X button (Jump in most games) |
| `circle` | O button |
| `square` | □ button (Attack in most games) |
| `triangle` | △ button |
| `start` | Start button |
| `select` | Select button |
| `up`, `down`, `left`, `right` | D-pad |
| `l1`, `l2`, `r1`, `r2` | Shoulder buttons |
| `l3`, `r3` | Analog stick buttons |

## Replaying Recordings

### With duckstation-regtest (Headless)

```bash
# Set BIOS directory
export DUCKSTATION_BIOS_DIR="/path/to/bios"

# Replay the recording
./build/bin/duckstation-regtest -console -frames 5000 \
  -input "$(cat ~/Library/Application\ Support/DuckStation/input_recording_12345.txt)" \
  /path/to/game.cue
```

### With Frame Dumps

```bash
# Replay and capture screenshots every 10 frames
./build/bin/duckstation-regtest -console -frames 5000 \
  -dumpdir ./replay_frames -dumpinterval 10 \
  -input "$(cat input_recording.txt)" \
  /path/to/game.cue
```

## Example: Recording Crash Bandicoot 3 Gameplay

### 1. Record in GUI

```
1. Open DuckStation
2. Load Crash Bandicoot 3
3. Navigate to the Warp Room
4. Press F5 to start recording
5. Make Crash jump and spin around
6. Press F5 to stop
7. Press F6 to save
```

### 2. Find the Recording

```bash
cat ~/Library/Application\ Support/DuckStation/input_recording_*.txt
# Output: 100:cross,140:cross:release,200:square,240:square:release,...
```

### 3. Replay Headlessly

```bash
export DUCKSTATION_BIOS_DIR="$HOME/workspace/ps/ps-bios"

./build/bin/duckstation-regtest -console -frames 10000 \
  -dumpdir /tmp/crash_replay -dumpinterval 25 \
  -input "$(cat ~/Library/Application\ Support/DuckStation/input_recording_*.txt)" \
  ../ps-games/Crash\ Bandicoot\ 3.cue
```

### 4. View the Replay

```bash
open /tmp/crash_replay/
```

## Tips

- **Start recording after loading** - Don't record the boot/loading screens unless needed
- **Keep recordings short** - Easier to manage and debug
- **Test your recording** - Replay it to make sure it works before relying on it
- **Frame timing matters** - PAL games run at 50fps, NTSC at 60fps

## Troubleshooting

### Recording not saving?
- Make sure you stopped recording (F5) before saving (F6)
- Check the OSD messages for errors

### Replay doesn't match?
- Ensure you're using the same game version/region
- Start from the same game state (use save states if needed)
- Check that frame counts match (PAL vs NTSC)

### Hotkeys not working?
- Verify hotkeys are bound in Settings → Hotkeys → System
- Make sure the game window has focus

