// font.h — OSD font character codes (font built by toold/make_font.py)
// $20-$7E: ASCII. Box drawing, shading and blocks live in the unused
// control codes $01-$1E; keep in sync with EXTRA in make_font.py.
#ifndef FONT_H
#define FONT_H

/* Box drawing, single line */
#define BOX_H    0x01   // ─
#define BOX_V    0x02   // │
#define BOX_TL   0x03   // ┌
#define BOX_TR   0x04   // ┐
#define BOX_BL   0x05   // └
#define BOX_BR   0x06   // ┘
#define BOX_T    0x07   // ┬
#define BOX_B    0x08   // ┴
#define BOX_L    0x09   // ├
#define BOX_R    0x0A   // ┤
#define BOX_X    0x0B   // ┼

/* Box drawing, double line */
#define BOX2_H   0x0C   // ═
#define BOX2_V   0x0D   // ║
#define BOX2_TL  0x0E   // ╔
#define BOX2_TR  0x0F   // ╗
#define BOX2_BL  0x10   // ╚
#define BOX2_BR  0x11   // ╝
#define BOX2_T   0x12   // ╦
#define BOX2_B   0x13   // ╩
#define BOX2_L   0x14   // ╠
#define BOX2_R   0x15   // ╣
#define BOX2_X   0x16   // ╬

/* Shading and blocks */
#define SHADE_LIGHT   0x17  // ░
#define SHADE_MEDIUM  0x18  // ▒
#define SHADE_DARK    0x19  // ▓
#define BLOCK_FULL    0x1A  // █
#define BLOCK_LOWER   0x1B  // ▄
#define BLOCK_LEFT    0x1C  // ▌
#define BLOCK_RIGHT   0x1D  // ▐
#define BLOCK_UPPER   0x1E  // ▀

#endif // FONT_H
