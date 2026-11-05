// OSD text layer in display coordinates, mixed over the NES picture.
//
// The text grid is the one the OSD firmware writes: 64 cells per row in memory
// (32 visible) x 30 rows, 8x8 glyphs in NES picture pixels, so each glyph pixel
// covers 2x2 display pixels like the picture. Text and attribute RAMs are written
// by the OSD CPU on wclk and read on the display clock, so neither the CPU nor a
// paused console disturbs the other side.
//
// Pipeline (display clock):
//   stage 0  h, v                 -> text / attribute RAM address
//   stage 1  char, attr  + picture (from nes_scaler / frame_buffer) -> font ROM
//   stage 2  OSD pixel over the picture index; raster signals delayed to match
module osd_overlay
    import display_pkg::*;
#(
    parameter FONT_FILE = "font.hex"    // untyped: Quartus doesn't support `string`
) (
    input  logic        clk,            // display clock
    input  logic        rst_n,

    // OSD CPU write port: text $2000-$27FF, attributes $2800-$2FFF
    input  logic        wclk,
    input  logic        text_we,
    input  logic        attr_we,
    input  logic [10:0] waddr,
    input  logic [7:0]  wdata,

    // stage 0 raster
    input  logic [9:0]  h,
    input  logic [9:0]  v,

    // stage 1: the picture pixel (nes_scaler outputs + frame buffer data)
    input  logic [9:0]  h1,
    input  logic [9:0]  v1,
    input  logic        image1,
    input  logic        hsync1,
    input  logic        vsync1,
    input  logic [5:0]  index1,

    // stage 2: picture with the OSD on top
    output logic [9:0]  h2,
    output logic [9:0]  v2,
    output logic        image2,
    output logic        hsync2,
    output logic        vsync2,
    output logic [5:0]  index2
);

    // ------ stage 0: cell of the picture pixel under (h, v)
    wire [9:0]  px0  = h - 10'(IMG_LEFT);           // picture x * 2 (garbage outside the picture)
    wire [10:0] cell_addr = {v[8:4], 1'b0, px0[8:4]};    // {row, col}, 64 cells per row

    logic [7:0] text [0:2047];
    logic [7:0] attr [0:2047];
    logic [7:0] char_code;
    logic [7:0] attr_code;

    always_ff @(posedge wclk) begin
        if (text_we)
            text[waddr] <= wdata;
        if (attr_we)
            attr[waddr] <= wdata;
    end

    always_ff @(posedge clk) begin
        char_code <= text[cell_addr];
        attr_code <= attr[cell_addr];
    end

    // ------ stage 1: glyph pixel
    wire [9:0] px1 = h1 - 10'(IMG_LEFT);
    logic [7:0] osd_pixel;              // NES palette index, 0 = transparent

    charmap #(
        .FONT_FILE(FONT_FILE)
    ) u_charmap (
        .clk(clk),
        .char_code(char_code[6:0]),
        .attr_code(attr_code),
        .row(v1[3:1]),
        .col(px1[3:1]),
        .pixels(osd_pixel)
    );

    // ------ stage 2
    logic [5:0] index_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h2      <= 10'd0;
            v2      <= 10'd0;
            image2  <= 1'b0;
            hsync2  <= 1'b0;
            vsync2  <= 1'b0;
            index_q <= 6'd0;
        end else begin
            h2      <= h1;
            v2      <= v1;
            image2  <= image1;
            hsync2  <= hsync1;
            vsync2  <= vsync1;
            index_q <= index1;
        end
    end

    assign index2 = (osd_pixel != 8'd0) ? osd_pixel[5:0] : index_q;

    wire unused = &{1'b0, v[9], v[3:0], px0[9], px0[3:0], px1[9:4], px1[0], v1[9:4], v1[0],
                    char_code[7], osd_pixel[7:6]};

endmodule
