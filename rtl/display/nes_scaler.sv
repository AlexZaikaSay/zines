// Maps the display raster onto the NES picture: each frame buffer pixel is shown
// as 2x2 display pixels, 512x480 centered with 64-pixel black borders.
// rx / ry address the frame buffer in the cycle of h / v; the raster signals come
// out one cycle later, aligned with the frame buffer's registered read data.
module nes_scaler
    import display_pkg::*;
(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [9:0] h,
    input  logic [9:0] v,
    input  logic       de,
    input  logic       hsync,
    input  logic       vsync,

    output logic [7:0] rx,              // frame buffer read address
    output logic [7:0] ry,

    // one cycle later, with the frame buffer data
    output logic [9:0] h_q,
    output logic [9:0] v_q,
    output logic       image_q,         // the pixel belongs to the NES picture
    output logic       hsync_q,
    output logic       vsync_q
);

    wire       image   = de && (h >= 10'(IMG_LEFT)) && (h < 10'(IMG_RIGHT));
    wire [9:0] image_x = h - 10'(IMG_LEFT);

    assign rx = image_x[8:1];
    assign ry = v[8:1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_q     <= 10'd0;
            v_q     <= 10'd0;
            image_q <= 1'b0;
            hsync_q <= 1'b0;
            vsync_q <= 1'b0;
        end else begin
            h_q     <= h;
            v_q     <= v;
            image_q <= image;
            hsync_q <= hsync;
            vsync_q <= vsync;
        end
    end

    wire unused = &{1'b0, image_x[9], image_x[0], v[9], v[0]};

endmodule
