// PPU dot / line counter and every dot-number decode of the PPU (ppu_timing_t).
// 341 dots x 262 lines; on odd frames with rendering enabled the pre-render line
// is one dot shorter.
module ppu_timing
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  logic        rendering_enabled,
    output logic [8:0]  scanline,
    output logic [8:0]  cycle,
    output ppu_timing_t timing
);

    logic odd_frame;

    wire line_end = (cycle == LAST_CYCLE) ||
                    (cycle == LAST_CYCLE - 1 && timing.prerender_line && odd_frame && rendering_enabled);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle     <= 0;
            scanline  <= PRERENDER_LINE;
            odd_frame <= 1'b0;
        end else if (ce) begin
            if (line_end) begin
                cycle <= 0;
                if (scanline == PRERENDER_LINE) begin
                    scanline  <= 0;
                    odd_frame <= ~odd_frame;
                end else begin
                    scanline <= scanline + 1;
                end
            end else begin
                cycle <= cycle + 1;
            end
        end
    end

    wire       visible_cycle = cycle >= 1 && cycle <= VISIBLE_WIDTH;
    wire [2:0] mod8_cycle    = cycle[2:0];

    assign timing.visible_line     = scanline < VISIBLE_HEIGHT;
    assign timing.visible_pixel    = timing.visible_line && visible_cycle;
    assign timing.prerender_line   = scanline == PRERENDER_LINE;
    assign timing.rendering_active = rendering_enabled & (timing.visible_line | timing.prerender_line);
    assign timing.left8            = cycle <= 8;
    assign timing.last_pixel       = cycle == 256;

    // Edges where a background tile has been fetched completely: the shifters
    // reload and coarse X is incremented
    assign timing.tile_edge        = (mod8_cycle == 0) &&
                                     ((cycle >= 8 && cycle <= 256) || cycle == 328 || cycle == 336);

    assign timing.bg_fetch_win     = visible_cycle || (cycle >= 321 && cycle <= 336);
    assign timing.bg_shift_win     = visible_cycle || (cycle >= 321 && cycle <= 336);
    assign timing.spr_fetch_win    = cycle >= 257 && cycle <= 320;
    assign timing.sec_clear        = cycle == 1;
    assign timing.eval_win         = cycle >= 65 && cycle <= 256;
    assign timing.inc_y            = cycle == 256;
    assign timing.copy_h           = cycle == 257;
    assign timing.copy_v           = timing.prerender_line && cycle >= 280 && cycle <= 304;
    assign timing.vblank_start     = scanline == 241 && cycle == 1;
    assign timing.vblank_end       = timing.prerender_line && cycle == 1;

endmodule
