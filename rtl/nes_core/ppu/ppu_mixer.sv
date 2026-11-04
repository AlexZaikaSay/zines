// Pixel mixer: background against the highest-priority sprite pixel, the left
// 8-pixel masks of PPUMASK and the sprite 0 hit test. Output: palette index.
module ppu_mixer
    import ppu_pkg::*;
(
    input  ppu_timing_t timing,
    input  logic        show_bg,
    input  logic        show_spr,
    input  logic        show_bg_left8,
    input  logic        show_spr_left8,
    input  logic [3:0]  bg_pix,
    input  logic        spr_found,
    input  logic [3:0]  spr_pix,
    input  logic        spr_behind,
    input  logic        spr0_opaque,
    output logic [4:0]  video,
    output logic        sprite0_hit_now
);
    wire left8          = timing.left8;
    wire bg_en          = show_bg  && !(left8 && !show_bg_left8);
    wire spr_en         = show_spr && !(left8 && !show_spr_left8);
    wire bg_opaque      = bg_en  && (bg_pix[1:0] != 2'b00);
    wire spr_opaque     = spr_en && spr_found;

    always_comb begin
        video = 0;
        if (timing.visible_pixel) begin
            if (bg_opaque && (!spr_opaque || spr_behind))
                video = {1'b0, bg_pix[3:0]};
            else if (spr_opaque)
                video = {1'b1, spr_pix};
        end
    end

    // Sprite 0 hit never triggers at x = 255 (cycle 256)
    assign sprite0_hit_now = timing.visible_pixel && bg_opaque && spr_en && spr0_opaque &&
                             !timing.last_pixel;

    wire unused = &{1'b0, timing};

endmodule
