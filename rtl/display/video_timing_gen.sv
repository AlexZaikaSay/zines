// The display raster: 800x525 grid of 640x480@60, the only source of display timing.
// h / v are registered; de / hsync / vsync are decoded from them in the same cycle
// (active high here; the output stage applies the negative sync polarity).
module video_timing_gen
    import display_pkg::*;
(
    input  logic       clk,             // pixel clock
    input  logic       rst_n,
    output logic [9:0] h,
    output logic [9:0] v,
    output logic       de,              // inside the visible 640x480
    output logic       hsync,
    output logic       vsync
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h <= 10'd0;
            v <= 10'd0;
        end else if (h == 10'(H_TOTAL - 1)) begin
            h <= 10'd0;
            v <= (v == 10'(V_TOTAL - 1)) ? 10'd0 : v + 10'd1;
        end else begin
            h <= h + 10'd1;
        end
    end

    assign de    = (h < 10'(H_VIS)) && (v < 10'(V_VIS));
    assign hsync = (h >= 10'(H_VIS + H_FRONT)) && (h < 10'(H_VIS + H_FRONT + H_SYNC));
    assign vsync = (v >= 10'(V_VIS + V_FRONT)) && (v < 10'(V_VIS + V_FRONT + V_SYNC));

endmodule
