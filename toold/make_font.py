#!/usr/bin/env python3
"""Convert unscii-8.hex (unifont .hex format) to font.hex for char_map.sv.

Input line format:  0041:183C66667E666600   (codepoint:16 hex digits = 8 rows)
Output: 1024 lines, one byte per line, address = code*8 + row.

Usage: python3 make_font.py unscii-8.hex font.hex
"""
import sys

CHARS, ROWS = 128, 8

src, dst = sys.argv[1], sys.argv[2]
font = [[0] * ROWS for _ in range(CHARS)]

with open(src) as f:
    for line in f:
        line = line.strip()
        if not line or ":" not in line:
            continue
        code_s, data = line.split(":", 1)
        code = int(code_s, 16)
        if code >= CHARS or len(data) != ROWS * 2:
            continue  # skip non-ASCII and non-8x8 glyphs
        font[code] = [int(data[i * 2:i * 2 + 2], 16) for i in range(ROWS)]

with open(dst, "w") as f:
    for glyph in font:
        for row in glyph:
            f.write(f"{row:02X}\n")

print(f"Wrote {CHARS * ROWS} bytes to {dst}")
