#!/usr/bin/env python3
"""Convert unscii-8.hex (unifont .hex format) to font.hex for charmap.sv.

Input line format:  0041:183C66667E666600   (codepoint:16 hex digits = 8 rows)
Output: 1024 lines, one byte per line, address = code*8 + row.

Codes $20-$7E are ASCII. The unused control codes $01-$1E hold box drawing,
shading and block glyphs (EXTRA below); keep in sync with osd/inc/font.h.

Usage: python3 make_font.py unscii-8.hex font.hex
"""
import sys

CHARS, ROWS = 128, 8

# Font code -> Unicode codepoint taken from unscii-8
EXTRA = {
    # single line
    0x01: 0x2500,  # ─
    0x02: 0x2502,  # │
    0x03: 0x250C,  # ┌
    0x04: 0x2510,  # ┐
    0x05: 0x2514,  # └
    0x06: 0x2518,  # ┘
    0x07: 0x252C,  # ┬
    0x08: 0x2534,  # ┴
    0x09: 0x251C,  # ├
    0x0A: 0x2524,  # ┤
    0x0B: 0x253C,  # ┼
    # double line
    0x0C: 0x2550,  # ═
    0x0D: 0x2551,  # ║
    0x0E: 0x2554,  # ╔
    0x0F: 0x2557,  # ╗
    0x10: 0x255A,  # ╚
    0x11: 0x255D,  # ╝
    0x12: 0x2566,  # ╦
    0x13: 0x2569,  # ╩
    0x14: 0x2560,  # ╠
    0x15: 0x2563,  # ╣
    0x16: 0x256C,  # ╬
    # shading and blocks
    0x17: 0x2591,  # ░
    0x18: 0x2592,  # ▒
    0x19: 0x2593,  # ▓
    0x1A: 0x2588,  # █
    0x1B: 0x2584,  # ▄
    0x1C: 0x258C,  # ▌
    0x1D: 0x2590,  # ▐
    0x1E: 0x2580,  # ▀
}

src, dst = sys.argv[1], sys.argv[2]
glyphs = {}

with open(src) as f:
    for line in f:
        line = line.strip()
        if not line or ":" not in line:
            continue
        code_s, data = line.split(":", 1)
        if len(data) != ROWS * 2:
            continue  # skip non-8x8 glyphs
        glyphs[int(code_s, 16)] = [int(data[i * 2:i * 2 + 2], 16) for i in range(ROWS)]

font = []
for code in range(CHARS):
    if code in EXTRA:
        codepoint = EXTRA[code]
    elif 0x20 <= code < 0x7F:
        codepoint = code
    else:
        font.append([0] * ROWS)  # NUL, unused control codes, DEL: blank
        continue
    if codepoint not in glyphs:
        print(f"warning: no glyph for U+{codepoint:04X}", file=sys.stderr)
    font.append(glyphs.get(codepoint, [0] * ROWS))

with open(dst, "w") as f:
    for rows in font:
        for row in rows:
            f.write(f"{row:02X}\n")

print(f"Wrote {CHARS * ROWS} bytes to {dst}")
