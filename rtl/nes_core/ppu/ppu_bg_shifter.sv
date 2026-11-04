// Background shift registers: two 16-bit pattern planes and two attribute planes.
// A fetched tile is loaded into the low byte (fetch.bg_tile_valid from ppu_vram_bus) while
// the previous one shifts out of the high byte; fine X picks the pixel bit.
module ppu_bg_shifter
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  ppu_fetch_t  fetch,          // bg_tile_valid: a complete tile is on bg_lo / data / bg_at
    input  logic [2:0]  fine_x,
    output logic [3:0]  bg_pix
);

    logic [15:0] pat_lo;
    logic [15:0] pat_hi;
    logic [15:0] att_lo;
    logic [15:0] att_hi;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pat_lo <= 0;
            pat_hi <= 0;
            att_lo <= 0;
            att_hi <= 0;
        end else if (ce && timing.rendering_active) begin
            if (timing.bg_shift_win) begin
                pat_lo <= {pat_lo[14:0], 1'b0};
                pat_hi <= {pat_hi[14:0], 1'b0};
                att_lo <= {att_lo[14:0], 1'b0};
                att_hi <= {att_hi[14:0], 1'b0};
            end
            if (fetch.bg_tile_valid) begin
                pat_lo[7:0] <= fetch.bg_lo;
                pat_hi[7:0] <= fetch.data;
                att_lo[7:0] <= {8{fetch.bg_at[0]}};
                att_hi[7:0] <= {8{fetch.bg_at[1]}};
            end
        end
    end

    wire [3:0] bsel = 4'd15 - {1'b0, fine_x};
    assign bg_pix   = {att_hi[bsel], att_lo[bsel], pat_hi[bsel], pat_lo[bsel]};

    wire unused = &{1'b0, timing, fetch};

endmodule
