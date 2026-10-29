`include "ppu/palette_ram.sv"

module ppu_sim (
    input  logic        clk,
    input  logic        rst_n,
    output logic [7:0]  pixel_color,
    output logic [8:0]  scanline,
    output logic [8:0]  cycle
);


    palette_ram u_palette_ram (
        .clk(clk),
        .addr(0),
        .data_in(0),
        .rw(1),
        .cs_n(1),
        .oe_n(1),
        .pixel_addr(0),
        .data_out(),
        .pixel_data_out(pixel_color)
    );

    logic       odd_frame;

    // ------ timing flags
    wire        prerender_line      = scanline == 261;
    wire        line_end            = (cycle == 340) ||
                                      (cycle == 339 && prerender_line && odd_frame);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle     <= 0;
            scanline  <= 261;
            odd_frame <= 1'b0;
        end else if (line_end) begin
            cycle <= 0;
            if (scanline == 261) begin
                scanline  <= 0;
                odd_frame <= ~odd_frame;
            end else begin
                scanline <= scanline + 1;
            end
        end else begin
            cycle <= cycle + 1;
        end
    end

endmodule
