#!/usr/bin/env python3
"""Build a 512 KiB byte image for an MX29F400C used in x16 mode.

The flash is treated as 256K x 16 words. Each selected HP ROM block maps to one
physical 32K-word bank. Input files are expected to contain CPU-visible 16-bit
words in big-endian byte order unless --little-endian-input is selected. Rev C
bitwise-complements every word by default for the non-inverting 74HCT245 path.

Example:
    python3 build_flash.py --manifest rom_manifest.csv -o mx29f400.bin
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

FLASH_WORDS = 256 * 1024
FLASH_BYTES = FLASH_WORDS * 2
WORDS_PER_HP_BLOCK = 32 * 1024
WORDS_PER_SEGMENT = 4 * 1024

# Map the HP octal ROM block number to the physical flash bank.
BLOCK_TO_BANK = {
    0o03: 0,
    0o05: 1,
    0o07: 2,
    0o11: 3,
    0o13: 4,
    0o21: 5,
    0o45: 6,
}


def parse_int(value: str) -> int:
    """Accept Python-style 0x/0o prefixes or ordinary decimal values."""
    return int(value.strip(), 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("-o", "--output", required=True, type=Path)
    parser.add_argument(
        "--little-endian-input",
        action="store_true",
        help="Treat each input word as low byte then high byte instead of big-endian.",
    )
    parser.add_argument(
        "--no-invert-data",
        action="store_true",
        help=(
            "Do not bitwise-complement ROM words. Rev C normally MUST complement "
            "data because its 74HCT245 bus transceivers are non-inverting."
        ),
    )
    args = parser.parse_args()

    # Erased NOR flash reads as all ones.
    image = bytearray(b"\xFF" * FLASH_BYTES)

    with args.manifest.open(newline="") as f:
        rows = csv.DictReader(f)
        for row in rows:
            src = Path(row["file"])
            hp_block = parse_int(row["hp_block"])
            segment = parse_int(row["segment"])

            if hp_block not in BLOCK_TO_BANK:
                raise ValueError(f"Unsupported HP ROM block: {hp_block:o} octal")
            if not 0 <= segment <= 7:
                raise ValueError(f"Segment must be 0..7: {segment}")

            data = src.read_bytes()
            if len(data) > WORDS_PER_SEGMENT * 2:
                raise ValueError(f"{src}: larger than one 4K-word ROM segment")
            if len(data) % 2:
                raise ValueError(f"{src}: odd byte count; expected 16-bit words")

            converted = bytearray()
            for i in range(0, len(data), 2):
                # Convert the input representation into a CPU-visible 16-bit word.
                if args.little_endian_input:
                    word = data[i] | (data[i + 1] << 8)
                else:
                    word = (data[i] << 8) | data[i + 1]

                # Rev C stores the physical active-low HP bus representation.
                # Thus a logical HP ROM word is complemented before being put in flash.
                if not args.no_invert_data:
                    word ^= 0xFFFF

                # Store output in big-endian word order. Change here if a specific
                # external programmer expects little-endian byte order.
                converted.extend(((word >> 8) & 0xFF, word & 0xFF))

            bank = BLOCK_TO_BANK[hp_block]
            word_offset = bank * WORDS_PER_HP_BLOCK + segment * WORDS_PER_SEGMENT
            byte_offset = word_offset * 2
            image[byte_offset:byte_offset + len(converted)] = converted

            print(
                f"{src}: HP block {hp_block:o}, segment {segment:o} -> "
                f"flash word 0x{word_offset:05X}"
            )

    args.output.write_bytes(image)
    print(f"Wrote {args.output} ({len(image)} bytes)")


if __name__ == "__main__":
    main()
