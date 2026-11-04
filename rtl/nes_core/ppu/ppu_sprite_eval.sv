// Sprite evaluation: during dots 65-256 of a visible line, scans the 64 OAM
// sprites and copies the first eight that cover the current scanline into
// secondary OAM, for ppu_sprites to fetch and draw on the next line.
//   Dot 1 clears secondary OAM to $FF. A sprite that is in range is copied
//   one byte per dot (Y, tile, attributes, X); a ninth one pulses ovf_pulse.
// OAM has a registered read, so sprite_index is the sprite of the next dot
// (eval_n_next): its bytes are on sprite_y.. when the FSM gets there.
module ppu_sprite_eval
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,
    input  ppu_timing_t timing,
    input  logic [8:0]  scanline,
    input  logic        rendering_enabled,
    input  logic        sprite_size_16,         // PPUCTRL bit 5: 8x16 sprites

    // primary OAM, one sprite at a time
    output logic [5:0]  sprite_index,           // read address, data one dot later
    input  logic [7:0]  sprite_y,
    input  logic [7:0]  sprite_tile,
    input  logic [7:0]  sprite_attr,
    input  logic [7:0]  sprite_x,

    // secondary OAM
    output sprite_t     sec_oam  [0:7],
    output logic [3:0]  spr_count,              // sprites found for the next line (0..8)
    output logic        ovf_pulse               // more than eight sprites on the line
);

    logic [6:0] eval_n;         // sprite under evaluation, 64 = done
    logic       copying;
    logic [1:0] copy_b;

    logic [6:0] eval_n_next;

    wire [8:0]  spr_size    = sprite_size_16 ? 9'd16 : 9'd8;
    wire [8:0]  eval_dif    = scanline - {1'b0, sprite_y};
    wire        eval_hit    = (scanline >= {1'b0, sprite_y}) && (eval_dif < spr_size);

    wire evaluating = rendering_enabled && timing.visible_line && timing.eval_win && eval_n < 64;

    // Next sprite to evaluate, decided ahead of the clock for the OAM read address
    always_comb begin
        eval_n_next = eval_n;
        if (timing.sec_clear)
            eval_n_next = 0;
        else if (evaluating) begin
            if (!copying) begin
                if (!eval_hit || spr_count >= 8)
                    eval_n_next = eval_n + 1;
            end else if (copy_b != 1 && copy_b != 2) begin
                eval_n_next = eval_n + 1;
            end
        end
    end

    assign sprite_index = eval_n_next[5:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eval_n    <= 0;
            spr_count <= 0;
            copying   <= 1'b0;
            copy_b    <= 0;
            ovf_pulse <= 1'b0;
            for (int k = 0; k < 8; k = k + 1)
                sec_oam[k] <= SPRITE_EMPTY;
        end else if (ce) begin
            ovf_pulse <= 1'b0;
            eval_n    <= eval_n_next;

            if (timing.sec_clear) begin
                spr_count <= 0;
                copying   <= 1'b0;
                copy_b    <= 0;
                for (int k = 0; k < 8; k = k + 1)
                    sec_oam[k] <= SPRITE_EMPTY;
            end
            else if (evaluating) begin
                if (!copying) begin
                    if (eval_hit) begin
                        if (spr_count < 8) begin
                            sec_oam[spr_count[2:0]].y   <= sprite_y;
                            sec_oam[spr_count[2:0]].is0 <= (eval_n == 0);
                            copying <= 1'b1;
                            copy_b  <= 1;
                        end else begin
                            ovf_pulse <= 1'b1;
                        end
                    end
                end else begin
                    copy_b <= copy_b + 1;
                    case (copy_b)
                        1: sec_oam[spr_count[2:0]].tile <= sprite_tile;
                        2: sec_oam[spr_count[2:0]].attr <= sprite_attr;
                        default: begin
                            sec_oam[spr_count[2:0]].x <= sprite_x;
                            spr_count <= spr_count + 1;
                            copying   <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

    wire unused = &{1'b0, timing};

endmodule
