// Display output stage: palette index -> RGB444, registered with the sync signals
// so nothing reaches the pins combinationally. 640x480@60 uses negative sync polarity.
// x / y give the raster position of the registered outputs, for encoders (HDMI)
// that generate their own sync and blanking from it.
module video_out
    import display_pkg::*;
(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [9:0] h,
    input  logic [9:0] v,
    input  logic       image,           // index is a picture pixel; black otherwise
    input  logic [5:0] index,
    input  logic       hsync,           // active high
    input  logic       vsync,

    output logic       hsync_n,
    output logic       vsync_n,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue,
    output logic [9:0] x,
    output logic [9:0] y
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync_n <= 1'b1;
            vsync_n <= 1'b1;
            {red, green, blue} <= 12'h000;
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            hsync_n <= ~hsync;
            vsync_n <= ~vsync;
            {red, green, blue} <= image ? nes_rgb(index) : 12'h000;
            x <= h;
            y <= v;
        end
    end

endmodule
