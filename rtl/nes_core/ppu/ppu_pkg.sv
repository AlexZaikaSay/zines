// Constants shared between ppu modules

/* verilator lint_off UNUSEDPARAM */
package ppu_pkg;

    localparam logic [8:0] LAST_CYCLE       = 340;
    localparam logic [8:0] PRERENDER_LINE   = 261;

    localparam logic [8:0] VISIBLE_WIDTH    = 256;
    localparam logic [8:0] VISIBLE_HEIGHT   = 240;

    localparam logic [2:0] PPUCTRL   = 0;
    localparam logic [2:0] PPUMASK   = 1;
    localparam logic [2:0] PPUSTATUS = 2;
    localparam logic [2:0] OAMADDR   = 3;
    localparam logic [2:0] OAMDATA   = 4;
    localparam logic [2:0] PPUSCROLL = 5;
    localparam logic [2:0] PPUADDR   = 6;
    localparam logic [2:0] PPUDATA   = 7;

    localparam logic [2:0] CTRL_INC     = 2;
    localparam logic [2:0] CTRL_SP_PAT  = 3;
    localparam logic [2:0] CTRL_BG      = 4;
    localparam logic [2:0] CTRL_SP_SIZE = 5;
    localparam logic [2:0] CTRL_NMI     = 7;

    localparam logic [2:0] MASK_8_BG_EN  = 1;
    localparam logic [2:0] MASK_8_SPR_EN = 2;
    localparam logic [2:0] MASK_BG_EN    = 3;
    localparam logic [2:0] MASK_SPR_EN   = 4;

    // Dot / line events, decoded once in ppu_timing. Every PPU module gets the whole
    // struct, so no other module compares cycle or scanline against dot numbers.
    typedef struct packed {
        logic visible_line;     // lines 0-239
        logic visible_pixel;    // visible line, dots 1-256
        logic prerender_line;   // line 261
        logic rendering_active; // rendering enabled on a visible or the pre-render line
        logic left8;            // dots 0-8: the left 8-pixel column
        logic last_pixel;       // dot 256: sprite 0 hit does not trigger here
        logic tile_edge;        // dots 8, 16 .. 256, 328, 336: coarse X steps
        logic bg_fetch_win;     // dots 1-256, 321-336: background fetches on the bus
        logic bg_shift_win;     // dots 1-256, 321-336: background shifters run
        logic spr_fetch_win;    // dots 257-320: sprite pattern fetches on the bus
        logic sec_clear;        // dot 1: secondary OAM is cleared
        logic eval_win;         // dots 65-256: sprite evaluation
        logic inc_y;            // dot 256: v moves to the next row
        logic copy_h;           // dot 257: horizontal bits t -> v
        logic copy_v;           // pre-render dots 280-304: vertical bits t -> v
        logic vblank_start;     // line 241, dot 1
        logic vblank_end;       // pre-render line, dot 1
    } ppu_timing_t;

    // One secondary-OAM entry: a sprite found on the line, as copied from OAM
    typedef struct packed {
        logic [7:0] y;
        logic [7:0] tile;
        logic [7:0] attr;
        logic [7:0] x;
        logic       is0;        // OAM sprite 0
    } sprite_t;

    // One-clk strobes of CPU accesses, decoded in ppu_regs for the register owners
    typedef struct packed {
        logic wr_ctrl;          // $2000 write
        logic wr_scroll;        // $2005 write
        logic wr_addr;          // $2006 write
        logic wr_data;          // $2007 write
        logic rd_data;          // $2007 read
        logic oam_we;           // $2004 write
        logic status_rd;        // $2002 read
    } ppu_cpu_strobe_t;

    // Render fetch results from ppu_vram_bus, each part valid on the dot named by its strobe
    typedef struct packed {
        logic [7:0] data;           // data of the read that ends this dot
        logic       bg_tile_valid;  // pattern high byte on data: tile complete
        logic [7:0] bg_lo;          //   with its pattern low byte
        logic [1:0] bg_at;          //   and its palette
        logic [2:0] spr_slot;       // sprite slot being fetched
        logic       spr_lo_valid;   // sprite pattern low byte on data
        logic       spr_hi_valid;   // sprite pattern high byte on data
    } ppu_fetch_t;

    localparam sprite_t SPRITE_EMPTY = '{y: 8'hFF, tile: 8'hFF, attr: 8'hFF, x: 8'hFF, is0: 1'b0};

    // ------ scroll helpers
    function automatic [14:0] inc_x(input [14:0] a);
        begin
            inc_x = a;
            if (a[4:0] == 31) begin
                inc_x[4:0] = 0;
                inc_x[10]  = ~a[10];
            end else begin
                inc_x[4:0] = a[4:0] + 1;
            end
        end
    endfunction

    function automatic [14:0] inc_y(input [14:0] a);
        begin
            inc_y = a;
            if (a[14:12] != 7) begin
                inc_y[14:12] = a[14:12] + 1;
            end else begin
                inc_y[14:12] = 0;
                if (a[9:5] == 29) begin
                    inc_y[9:5] = 0;
                    inc_y[11]  = ~a[11];
                end else if (a[9:5] == 31) begin
                    inc_y[9:5] = 0;
                end else begin
                    inc_y[9:5] = a[9:5] + 1;
                end
            end
        end
    endfunction

    function automatic [7:0] reverse_byte(input [7:0] b);
        reverse_byte = {b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]};
    endfunction

endpackage
/* verilator lint_on UNUSEDPARAM */
