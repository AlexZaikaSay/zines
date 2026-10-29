// Font ROM 8x8, 128 characters (ASCII + box drawing in $01-$1E) = 1024 bytes = 1 M9K.
// Address = {char_code, row}, data = 8 pixels of one row (bit 7 = leftmost pixel).
// Synchronous read: 1 cycle latency.
module charmap #(
    parameter string FONT_FILE = "font.hex"
) (
    input  logic       clk,
    input  logic [6:0] char_code,   // character code 0..127
    input  logic [7:0] attr_code,   // attribute code 
    input  logic [2:0] row,         // glyph row
    input  logic [2:0] col,         // glyph column
    output logic [7:0] pixels       // color
);

    (* romstyle = "M9K" *) logic [7:0] rom [0:1023];

    // 16-color index -> NES palette index (closest match in the 64-color
    // palette). $00 is avoided: the board treats OSD pixel 0 as transparent.
    localparam logic [7:0] PIXEL_COLOR [0:15] = '{
        8'h0F,  //  0 black
        8'h02,  //  1 blue
        8'h1A,  //  2 green
        8'h1C,  //  3 cyan
        8'h16,  //  4 red
        8'h14,  //  5 magenta
        8'h17,  //  6 brown
        8'h10,  //  7 light gray
        8'h2D,  //  8 dark gray
        8'h12,  //  9 light blue
        8'h2A,  // 10 light green
        8'h2C,  // 11 light cyan
        8'h26,  // 12 light red
        8'h24,  // 13 light magenta
        8'h28,  // 14 yellow
        8'h30   // 15 white
    };

/* Attribute byte, one per character cell (same layout as OSD_TEXT):
 *   [3:0] FG color index (16-color palette)
 *   [6:4] BG color index (8-color palette)
 *   [7]   transparent flag (0 = transparent)
 */

    initial $readmemh(FONT_FILE, rom);

    // Font pixel set -> FG color, clear -> BG color. Without bit 7 the BG
    // is transparent (pixels = 0, the game shows through), so untouched
    // cells (attr 0) do not cover the picture. attr_code must arrive together
    // with char_code, so both share the 1-cycle ROM latency.
    always_ff @(posedge clk)
        if (rom[{char_code, row}][7-col])
            pixels <= PIXEL_COLOR[attr_code[3:0]];
        else if (!attr_code[7])
            pixels <= 8'h00;
        else
            pixels <= PIXEL_COLOR[{1'b0, attr_code[6:4]}];

endmodule
