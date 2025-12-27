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

# Known memory addresses for popular games
KNOWN_ADDRESSES = {
    "crash3": {
        "lives": (0x80068F58, 1, "Lives"),
        "wumpa": (0x80068F5C, 2, "Wumpa Fruits"),
        "crystals": (0x80068F60, 4, "Crystals"),
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
    
    # Default: show some stats
    print(f"\nRAM dump info:")
    print(f"  Size: {len(data)} bytes ({len(data) / 1024 / 1024:.2f} MB)")
    print(f"  Non-zero bytes: {sum(1 for b in data if b != 0)}")
    print(f"\nUse --address 0x80XXXXXX to read specific memory")
    print(f"Use --game crash3 to see known addresses")
    print(f"Use --diff file1.bin file2.bin to compare dumps")


if __name__ == "__main__":
    main()

