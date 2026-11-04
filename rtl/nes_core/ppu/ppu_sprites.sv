// Sprite rendering for the current line: eight ppu_sprite_unit slots fed from
// secondary OAM, the pattern fetch address for dots 256-319 and the priority
// between the slots (the lowest slot with an opaque pixel wins).
//   The fetch schedule comes from ppu_vram_bus: fetch.spr_slot is the slot on the bus,
//   fetch.spr_lo_valid / spr_hi_valid mark the dots its pattern bytes arrive.
module ppu_sprites
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  logic [8:0]  scanline,
    input  logic        sprite_size_16,         // PPUCTRL bit 5: 8x16 sprites
    input  logic        sprite_pattern_table,   // PPUCTRL bit 3: 8x8 sprite table at $1000
    input  sprite_t     sec_oam  [0:7],                // secondary OAM
    input  logic [3:0]  spr_count,              // sprites in secondary OAM (0..8)
    input  ppu_fetch_t  fetch,                  // spr_slot / spr_lo_valid / spr_hi_valid, data
    output logic [13:0] spr_pat_addr,           // low plane; the high plane is | $0008
    output logic        spr_found,
    output logic [3:0]  spr_pix,                // {palette, color}
    output logic        spr_behind,
    output logic        spr0_opaque
);

    // ------ pattern address of the slot being fetched
    wire [2:0]  slot        = fetch.spr_slot;

    wire [3:0]  cur_y       = sec_oam[slot].y[3:0];
    wire [7:0]  cur_tile    = sec_oam[slot].tile;
    wire [3:0]  spr_row     = scanline[3:0] - cur_y;
    wire        spr_vflip   = sec_oam[slot].attr[7];
    wire [2:0]  fr8         = spr_vflip ? (3'd7 - spr_row[2:0]) : spr_row[2:0];
    wire [3:0]  fr16        = spr_vflip ? (4'd15 - spr_row)     : spr_row;

    assign spr_pat_addr = sprite_size_16
                            ? {1'b0, cur_tile[0], cur_tile[7:1], fr16[3], 1'b0, fr16[2:0]}
                            : {1'b0, sprite_pattern_table, cur_tile, 1'b0, fr8};

    // ------ slots
    wire shift = timing.visible_pixel && !fetch.spr_lo_valid && !fetch.spr_hi_valid;

    logic [1:0] pixel   [0:7];
    logic [1:0] palette [0:7];
    logic       behind  [0:7];
    logic       is0     [0:7];

    genvar n;
    generate
        for (n = 0; n < 8; n = n + 1) begin : g_slot
            ppu_sprite_unit u_unit (
                .clk(clk),
                .rst_n(rst_n),
                .ce(ce),
                .active(timing.rendering_active),
                .load_lo(fetch.spr_lo_valid && slot == 3'(n)),
                .load_hi(fetch.spr_hi_valid && slot == 3'(n)),
                .shift(shift),
                .valid(4'(n) < spr_count),
                .pattern(fetch.data),
                .x(sec_oam[n].x),
                .attr(sec_oam[n].attr),
                .is0_in(sec_oam[n].is0),
                .pixel(pixel[n]),
                .palette(palette[n]),
                .behind(behind[n]),
                .is0(is0[n])
            );

            // only the low four bits of Y are needed for the row in the tile
            wire unused_y = &{1'b0, sec_oam[n].y[7:4]};
        end
    endgenerate

    // ------ priority: the lowest opaque slot is shown; sprite 0 counts in any slot
    always_comb begin
        spr_found   = 1'b0;
        spr_pix     = 4'd0;
        spr_behind  = 1'b0;
        spr0_opaque = 1'b0;
        for (int i = 0; i < 8; i = i + 1) begin
            if (pixel[i] != 2'b00) begin
                if (is0[i])
                    spr0_opaque = 1'b1;
                if (!spr_found) begin
                    spr_found  = 1'b1;
                    spr_pix    = {palette[i], pixel[i]};
                    spr_behind = behind[i];
                end
            end
        end
    end

    wire unused = &{1'b0, timing, fetch, scanline[8:4]};

endmodule
