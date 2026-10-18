// Font ROM 8x8, 128 ASCII characters = 1024 bytes = 1 M9K.
// Address = {char_code, row}, data = 8 pixels of one row (bit 7 = leftmost pixel).
// Synchronous read: 1 cycle latency.
module charmap #(
    parameter string FONT_FILE = "font.hex"
) (
    input  logic       clk,
    input  logic [6:0] char_code,   // ASCII code 0..127
    input  logic [2:0] row,         // glyph row
    input  logic [2:0] col,         // glyph column
    output logic [7:0] pixels       // row bits, [7] = left pixel
);

    (* romstyle = "M9K" *) logic [7:0] rom [0:1023];

    initial $readmemh(FONT_FILE, rom);

    always_ff @(posedge clk)
        pixels <= 8'(rom[{char_code, row}][7-col]);

endmodule
