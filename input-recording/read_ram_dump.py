#!/usr/bin/env python3
"""
Read and analyze PS1 RAM dumps from DuckStation input recordings.

Usage:
    python read_ram_dump.py <ram_dump.bin> [--address 0x80068F58] [--size 4]
    python read_ram_dump.py <ram_dump.bin> --watch-file watches.txt
    python read_ram_dump.py <dump1.bin> <dump2.bin> --diff
"""

import argparse
import struct
import sys
from pathlib import Path

# PS1 RAM base address
RAM_BASE = 0x80000000
RAM_SIZE = 2 * 1024 * 1024  # 2MB

# Known memory addresses for popular games (multiple regions)
# NOTE: These addresses vary by game version/region. Use --find-lives to discover yours.
KNOWN_ADDRESSES = {
    "crash3": {
        # NTSC-U (US) addresses - SCUS-94900
        "lives_us": (0x80068F58, 1, "Lives (US)"),
        "wumpa_us": (0x80068F5C, 2, "Wumpa Fruits (US)"),
        "crystals_us": (0x80068F60, 4, "Crystals (US)"),
        # PAL (Europe) addresses - SCES-01420
        "lives_pal": (0x80069A78, 1, "Lives (PAL)"),
        "wumpa_pal": (0x80069A7C, 2, "Wumpa Fruits (PAL)"),
        # NTSC-J (Japan) addresses - SCPS-10073
        "lives_jp": (0x80068E58, 1, "Lives (JP)"),
    },
    "crash2": {
        "lives": (0x800673A0, 1, "Lives"),
        "wumpa": (0x800673A4, 2, "Wumpa Fruits"),
    },
}


def read_value(data: bytes, address: int, size: int) -> int:
    """Read a value from RAM dump at the given PS1 address."""
    offset = address - RAM_BASE
    if offset < 0 or offset + size > len(data):
        raise ValueError(f"Address 0x{address:08X} out of range")
    
    if size == 1:
        return data[offset]
    elif size == 2:
        return struct.unpack_from("<H", data, offset)[0]
    elif size == 4:
        return struct.unpack_from("<I", data, offset)[0]
    else:
        raise ValueError(f"Unsupported size: {size}")


def read_ram_dump(filepath: str) -> bytes:
    """Read a RAM dump file."""
    with open(filepath, "rb") as f:
        data = f.read()
    
    if len(data) != RAM_SIZE:
        print(f"Warning: Expected {RAM_SIZE} bytes, got {len(data)}", file=sys.stderr)
    
    return data


def print_hex_dump(data: bytes, address: int, length: int = 64):
    """Print a hex dump of memory at the given address."""
    offset = address - RAM_BASE
    end = min(offset + length, len(data))
    
    print(f"\nHex dump at 0x{address:08X}:")
    print("-" * 60)
    
    for i in range(offset, end, 16):
        hex_part = " ".join(f"{data[j]:02X}" for j in range(i, min(i + 16, end)))
        ascii_part = "".join(
            chr(data[j]) if 32 <= data[j] < 127 else "."
            for j in range(i, min(i + 16, end))
        )
        print(f"0x{RAM_BASE + i:08X}: {hex_part:<48} {ascii_part}")


def compare_dumps(data1: bytes, data2: bytes, threshold: int = 100):
    """Compare two RAM dumps and show differences."""
    differences = []
    
    for i in range(min(len(data1), len(data2))):
        if data1[i] != data2[i]:
            differences.append((RAM_BASE + i, data1[i], data2[i]))
    
    print(f"\nFound {len(differences)} byte differences")
    
    if len(differences) > threshold:
        print(f"(showing first {threshold})")
        differences = differences[:threshold]
    
    print("-" * 50)
    print(f"{'Address':<14} {'Before':<8} {'After':<8} {'Delta'}")
    print("-" * 50)
    
    for addr, v1, v2 in differences:
        delta = v2 - v1
        print(f"0x{addr:08X}     0x{v1:02X}     0x{v2:02X}     {delta:+d}")


def load_watches(filepath: str) -> list:
    """Load memory watches from a file."""
    watches = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(",")
            if len(parts) >= 3:
                name = parts[0].strip()
                address = int(parts[1].strip(), 16)
                size = int(parts[2].strip())
                watches.append((name, address, size))
    return watches


def search_value(data: bytes, value: int, size: int = 1, max_results: int = 50) -> list:
    """Search for all addresses containing a specific value."""
    results = []
    
    if size == 1:
        for i in range(len(data)):
            if data[i] == value:
                results.append(RAM_BASE + i)
                if len(results) >= max_results:
                    break
    elif size == 2:
        for i in range(len(data) - 1):
            v = struct.unpack_from("<H", data, i)[0]
            if v == value:
                results.append(RAM_BASE + i)
                if len(results) >= max_results:
                    break
    elif size == 4:
        for i in range(len(data) - 3):
            v = struct.unpack_from("<I", data, i)[0]
            if v == value:
                results.append(RAM_BASE + i)
                if len(results) >= max_results:
                    break
    
    return results


def search_range(data: bytes, min_val: int, max_val: int, size: int = 1, max_results: int = 50) -> list:
    """Search for addresses with values in a range."""
    results = []
    
    if size == 1:
        for i in range(len(data)):
            if min_val <= data[i] <= max_val:
                results.append((RAM_BASE + i, data[i]))
                if len(results) >= max_results:
                    break
    elif size == 2:
        for i in range(len(data) - 1):
            v = struct.unpack_from("<H", data, i)[0]
            if min_val <= v <= max_val:
                results.append((RAM_BASE + i, v))
                if len(results) >= max_results:
                    break
    elif size == 4:
        for i in range(len(data) - 3):
            v = struct.unpack_from("<I", data, i)[0]
            if min_val <= v <= max_val:
                results.append((RAM_BASE + i, v))
                if len(results) >= max_results:
                    break
    
    return results


def find_lives_address(data1: bytes, data2: bytes, expected_before: int, expected_after: int) -> list:
    """Find addresses where value changed from expected_before to expected_after (e.g., lives decreasing)."""
    results = []
    
    for i in range(len(data1)):
        if data1[i] == expected_before and data2[i] == expected_after:
            results.append(RAM_BASE + i)
    
    return results


def find_changed_by_delta(data1: bytes, data2: bytes, delta: int, size: int = 1) -> list:
    """Find addresses where value changed by exactly delta (e.g., -1 for losing a life)."""
    results = []
    
    if size == 1:
        for i in range(len(data1)):
            diff = data2[i] - data1[i]
            if diff == delta and data1[i] > 0 and data1[i] < 100:  # Reasonable game values
                results.append((RAM_BASE + i, data1[i], data2[i]))
    elif size == 2:
        for i in range(len(data1) - 1):
            v1 = struct.unpack_from("<H", data1, i)[0]
            v2 = struct.unpack_from("<H", data2, i)[0]
            diff = v2 - v1
            if diff == delta and v1 > 0 and v1 < 10000:
                results.append((RAM_BASE + i, v1, v2))
    
    return results


def main():
    parser = argparse.ArgumentParser(description="Read PS1 RAM dumps")
    parser.add_argument("files", nargs="+", help="RAM dump file(s)")
    parser.add_argument("--address", "-a", help="Address to read (e.g., 0x80068F58)")
    parser.add_argument("--size", "-s", type=int, default=4, help="Size in bytes (1, 2, or 4)")
    parser.add_argument("--hex", "-x", action="store_true", help="Show hex dump at address")
    parser.add_argument("--hex-length", type=int, default=64, help="Hex dump length")
    parser.add_argument("--diff", "-d", action="store_true", help="Compare two dumps")
    parser.add_argument("--watch-file", "-w", help="File with memory watches")
    parser.add_argument("--game", "-g", choices=list(KNOWN_ADDRESSES.keys()), 
                        help="Use known addresses for a game")
    parser.add_argument("--search", type=int, help="Search for addresses containing this value")
    parser.add_argument("--search-range", nargs=2, type=int, metavar=("MIN", "MAX"),
                        help="Search for values in range (e.g., --search-range 1 10)")
    parser.add_argument("--find-lives", nargs=2, type=int, metavar=("BEFORE", "AFTER"),
                        help="Find lives address: --find-lives 5 4 (had 5 lives, now 4)")
    parser.add_argument("--find-delta", type=int, 
                        help="Find addresses that changed by this delta (e.g., -1 for lost life)")
    parser.add_argument("--max-results", type=int, default=50, help="Max search results")
    
    args = parser.parse_args()
    
    # Load first dump
    data = read_ram_dump(args.files[0])
    print(f"Loaded: {args.files[0]} ({len(data)} bytes)")
    
    # Compare mode
    if args.diff and len(args.files) >= 2:
        data2 = read_ram_dump(args.files[1])
        print(f"Loaded: {args.files[1]} ({len(data2)} bytes)")
        compare_dumps(data, data2)
        return
    
    # Find lives address (needs 2 dumps)
    if args.find_lives and len(args.files) >= 2:
        data2 = read_ram_dump(args.files[1])
        print(f"Loaded: {args.files[1]} ({len(data2)} bytes)")
        before, after = args.find_lives
        results = find_lives_address(data, data2, before, after)
        print(f"\nSearching for addresses that changed from {before} to {after}:")
        print("-" * 50)
        if results:
            print(f"Found {len(results)} candidate addresses:")
            for addr in results[:args.max_results]:
                print(f"  0x{addr:08X}")
            if len(results) > args.max_results:
                print(f"  ... and {len(results) - args.max_results} more")
        else:
            print("No matches found. Try different before/after values.")
        return
    
    # Find addresses that changed by delta
    if args.find_delta is not None and len(args.files) >= 2:
        data2 = read_ram_dump(args.files[1])
        print(f"Loaded: {args.files[1]} ({len(data2)} bytes)")
        results = find_changed_by_delta(data, data2, args.find_delta, args.size)
        print(f"\nSearching for addresses that changed by {args.find_delta:+d}:")
        print("-" * 50)
        if results:
            print(f"Found {len(results)} candidate addresses:")
            for addr, v1, v2 in results[:args.max_results]:
                print(f"  0x{addr:08X}: {v1} -> {v2}")
            if len(results) > args.max_results:
                print(f"  ... and {len(results) - args.max_results} more")
        else:
            print("No matches found.")
        return
    
    # Read specific address
    if args.address:
        address = int(args.address, 16)
        value = read_value(data, address, args.size)
        print(f"\n0x{address:08X} ({args.size} bytes): {value} (0x{value:0{args.size*2}X})")
        
        if args.hex:
            print_hex_dump(data, address, args.hex_length)
        return
    
    # Use known game addresses
    if args.game:
        print(f"\nKnown addresses for {args.game}:")
        print("-" * 40)
        for name, (addr, size, desc) in KNOWN_ADDRESSES[args.game].items():
            value = read_value(data, addr, size)
            print(f"{desc:<20} 0x{addr:08X}: {value}")
        return
    
    # Load watches from file
    if args.watch_file:
        watches = load_watches(args.watch_file)
        print(f"\nMemory watches from {args.watch_file}:")
        print("-" * 50)
        for name, addr, size in watches:
            value = read_value(data, addr, size)
            print(f"{name:<20} 0x{addr:08X} ({size}B): {value}")
        return
    
    # Search for specific value
    if args.search is not None:
        results = search_value(data, args.search, args.size, args.max_results)
        print(f"\nSearching for value {args.search} ({args.size} byte{'s' if args.size > 1 else ''}):")
        print("-" * 40)
        if results:
            print(f"Found {len(results)} addresses:")
            for addr in results:
                print(f"  0x{addr:08X}")
        else:
            print("No matches found")
        return
    
    # Search for value range
    if args.search_range:
        min_val, max_val = args.search_range
        results = search_range(data, min_val, max_val, args.size, args.max_results)
        print(f"\nSearching for values {min_val}-{max_val} ({args.size} byte{'s' if args.size > 1 else ''}):")
        print("-" * 40)
        if results:
            print(f"Found {len(results)} addresses:")
            for addr, val in results:
                print(f"  0x{addr:08X}: {val}")
        else:
            print("No matches found")
        return
    
    # Default: show some stats
    print(f"\nRAM dump info:")
    print(f"  Size: {len(data)} bytes ({len(data) / 1024 / 1024:.2f} MB)")
    print(f"  Non-zero bytes: {sum(1 for b in data if b != 0)}")
    print(f"\nUsage examples:")
    print(f"  --address 0x80068F58 --size 1    Read specific address")
    print(f"  --game crash3                    Show known addresses (may not match your version)")
    print(f"  --search 4 --size 1              Find all addresses with value 4")
    print(f"  --search-range 1 10              Find values between 1 and 10")
    print(f"  --diff file1.bin file2.bin       Compare two dumps")
    print(f"")
    print(f"To find YOUR game's lives address:")
    print(f"  1. Record gameplay, die once to lose a life")
    print(f"  2. Run: python {sys.argv[0]} before.bin after.bin --find-lives 5 4")
    print(f"     (if you had 5 lives before, 4 after)")
    print(f"  3. Or use: --find-delta -1 to find anything that decreased by 1")


if __name__ == "__main__":
    main()

