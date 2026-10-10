`include "ppu/palette_ram.sv"

// NES PPU (2C02) - simplified, dot-based implementation.
//
// Conventions
//  * One `clk` = one PPU dot. `cycle` (0..340) / `scanline` (0..261, 261 = pre-render).
//  * CPU port: cpu_rw = 1 is a read, 0 is a write. Every access must be presented for
//    exactly one clk. Reads of $2000/$2001/$2003/$2005/$2006 and writes to $2002 are no-ops.
//  * The external VRAM bus (ppu_addr/ppu_data_out/ppu_rd_n/ppu_wr_n) is owned by this
//    module only. A read is two clocks: the address and ppu_rd_n = 0 are registered on
//    edge N, memory answers on edge N+1, the PPU samples ppu_data_in on edge N+2.
//  * While rendering is active the bus belongs to the renderer; CPU accesses to $2007
//    are ignored then (real hardware glitches in that case).
//  * $2007 reads return the read buffer; palette reads are not forwarded immediately.
module ppu2C02 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ppu_cs_n,
    input  logic        cpu_rw,
    input  logic [2:0]  cpu_addr,
    input  logic [7:0]  cpu_data_in,
    input  logic [7:0]  ppu_data_in,   // external VRAM data bus
    output logic [7:0]  cpu_data_out,
    output logic [13:0] ppu_addr,
    output logic [7:0]  ppu_data_out,
    output logic        nmi_n,
    output logic        ppu_rd_n,
    output logic        ppu_wr_n,
    output logic [4:0]  video,
    output logic [7:0]  pixel_color
);

    // Palette RAM lives inside the PPU: $3F00-$3FFF never reaches the external bus
    logic        rd_n_q;
    logic        wr_n_q;
    logic [7:0]  palette_data;
    wire         palette_sel = (ppu_addr[13:8] == 6'h3F);
    wire  [7:0]  bus_data_in = palette_sel ? palette_data : ppu_data_in;

    assign ppu_rd_n = rd_n_q || palette_sel;
    assign ppu_wr_n = wr_n_q || palette_sel;

    // $3F10/14/18/1C mirror $3F00/04/08/0C
    function automatic [4:0] mirror_palette_addr(input [4:0] addr);
        mirror_palette_addr = (addr[1:0] == 2'b00) ? {1'b0, addr[3:0]} : addr;
    endfunction

    palette_ram u_palette_ram (
        .clk(clk),
        .addr(mirror_palette_addr(ppu_addr[4:0])),
        .data_in(ppu_data_out),
        .rw(wr_n_q),
        .cs_n(!palette_sel),
        .oe_n(rd_n_q),
        .pixel_addr(mirror_palette_addr(video)),
        .data_out(palette_data),
        .pixel_data_out(pixel_color)
    );

    localparam PPUCTRL   = 0;
    localparam PPUMASK   = 1;
    localparam PPUSTATUS = 2;
    localparam OAMADDR   = 3;
    localparam OAMDATA   = 4;
    localparam PPUSCROLL = 5;
    localparam PPUADDR   = 6;
    localparam PPUDATA   = 7;

    localparam CTRL_INC     = 2;
    localparam CTRL_SP_PAT  = 3;
    localparam CTRL_BG      = 4;
    localparam CTRL_SP_SIZE = 5;
    localparam CTRL_NMI     = 7;

    localparam MASK_8_BG_EN  = 1;
    localparam MASK_8_SPR_EN = 2;
    localparam MASK_BG_EN    = 3;
    localparam MASK_SPR_EN   = 4;

    // ------ state
    logic [7:0]  ppu_ctrl;
    logic [7:0]  ppu_mask;
    logic [7:0]  oam_addr;
    logic [7:0]  oam [0:255];
    logic        write_toggle;
    logic        odd_frame;
    logic [7:0]  read_buffer;
    logic [1:0]  rd_cnt;          // $2007 read in flight

    logic [14:0] v_addr;          // current VRAM address
    logic [14:0] t_addr;          // temporary VRAM address
    logic [2:0]  fine_x;

    logic [8:0]  cycle;
    logic [8:0]  scanline;

    logic        vblank_flag;
    logic        sprite0_hit_flag;
    logic        sprite_overflow;
    logic        ovf_pulse;
    logic        sprite0_hit_now;

    initial begin : oam_init
        integer n;
        for (n = 0; n < 256; n = n + 1) oam[n] = 8'hFF;
    end

    // ------ timing flags
    wire        rendering_enabled   = ppu_mask[MASK_BG_EN] | ppu_mask[MASK_SPR_EN];
    wire        visible_cycle       = cycle >= 1 && cycle <= 256;
    wire        visible_line        = scanline < 240;
    wire        visible_pixel       = visible_line && visible_cycle;
    wire        prerender_line      = scanline == 261;
    wire        rendering_active    = rendering_enabled & (visible_line | prerender_line);
    wire [2:0]  mod8_cycle          = cycle[2:0];

    // Edges where a background tile has been fetched completely and the shifters reload.
    // Coarse X is incremented on the same edges.
    wire        tile_edge           = (mod8_cycle == 0) &&
                                      ((cycle >= 8 && cycle <= 256) || cycle == 328 || cycle == 336);

    wire        bg_fetch_win        = (cycle <= 255) || (cycle >= 320 && cycle <= 335);
    wire        bg_shift_win        = visible_cycle || (cycle >= 321 && cycle <= 336);
    wire        spr_fetch_win       = (cycle >= 256 && cycle <= 319);
    wire        spr_cap_hi          = (mod8_cycle == 0) && (cycle >= 264 && cycle <= 320);

    wire        line_end            = (cycle == 340) ||
                                      (cycle == 339 && prerender_line && odd_frame && rendering_enabled);

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

    // --- secondary OAM / sprite evaluation
    logic [7:0] sec_y    [0:7];
    logic [7:0] sec_tile [0:7];
    logic [7:0] sec_attr [0:7];
    logic [7:0] sec_x    [0:7];
    logic       sec_is0  [0:7];

    logic [6:0] eval_n;       // sprite under evaluation, 64 = done
    logic [3:0] spr_count;    // sprites found for the next line (0..8)
    logic       copying;
    logic [1:0] copy_b;

    wire [7:0]  eval_y      = oam[{eval_n[5:0], 2'b00}];
    wire [7:0]  eval_tile   = oam[{eval_n[5:0], 2'b01}];
    wire [7:0]  eval_attr   = oam[{eval_n[5:0], 2'b10}];
    wire [7:0]  eval_x      = oam[{eval_n[5:0], 2'b11}];
    wire [8:0]  spr_size    = ppu_ctrl[CTRL_SP_SIZE] ? 16 : 8;
    wire [8:0]  eval_dif    = scanline - {1'b0, eval_y};
    wire        eval_hit    = (scanline >= {1'b0, eval_y}) && (eval_dif < spr_size);

    integer k;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eval_n    <= 0;
            spr_count <= 0;
            copying   <= 1'b0;
            copy_b    <= 0;
            ovf_pulse <= 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                sec_y[k]    <= 8'hFF;
                sec_tile[k] <= 8'hFF;
                sec_attr[k] <= 8'hFF;
                sec_x[k]    <= 8'hFF;
                sec_is0[k]  <= 1'b0;
            end
        end else begin
            ovf_pulse <= 1'b0;

            if (cycle == 1) begin
                eval_n    <= 0;
                spr_count <= 0;
                copying   <= 1'b0;
                copy_b    <= 0;
                for (k = 0; k < 8; k = k + 1) begin
                    sec_y[k]    <= 8'hFF;
                    sec_tile[k] <= 8'hFF;
                    sec_attr[k] <= 8'hFF;
                    sec_x[k]    <= 8'hFF;
                    sec_is0[k]  <= 1'b0;
                end
            end 
            else if (rendering_enabled && visible_line &&
                         cycle >= 65 && cycle <= 256 && eval_n < 64) begin
                if (!copying) begin
                    if (eval_hit) begin
                        if (spr_count < 8) begin
                            sec_y[spr_count[2:0]]   <= eval_y;
                            sec_is0[spr_count[2:0]] <= (eval_n == 0);
                            copying <= 1'b1;
                            copy_b  <= 1;
                        end else begin
                            ovf_pulse <= 1'b1;
                            eval_n    <= eval_n + 1;
                        end
                    end else begin
                        eval_n <= eval_n + 1;
                    end
                end else begin
                    copy_b <= copy_b + 1;
                    case (copy_b)
                        1: sec_tile[spr_count[2:0]] <= eval_tile;
                        2: sec_attr[spr_count[2:0]] <= eval_attr;
                        default: begin
                            sec_x[spr_count[2:0]] <= eval_x;
                            spr_count <= spr_count + 1;
                            eval_n    <= eval_n + 1;
                            copying   <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

    // ------ sprite pattern address
    wire [2:0]  slot        = cycle[5:3];
    wire [3:0]  cur_y       = sec_y[slot][3:0];
    wire [7:0]  cur_tile    = sec_tile[slot];
    wire [7:0]  cur_attr    = sec_attr[slot];
    wire [3:0]  spr_row     = scanline[3:0] - cur_y[3:0];
    wire        spr_vflip   = cur_attr[7];
    wire [2:0]  fr8         = spr_vflip
                                ? (7 - spr_row[2:0]) 
                                : spr_row[2:0];

    wire [3:0]  fr16        = spr_vflip 
                                ? (15 - spr_row) 
                                : spr_row;

    wire [13:0] spr_addr_lo = ppu_ctrl[CTRL_SP_SIZE]
                                ? {1'b0, cur_tile[0], cur_tile[7:1], fr16[3], 1'b0, fr16[2:0]}
                                : {1'b0, ppu_ctrl[CTRL_SP_PAT], cur_tile, 1'b0, fr8};

    // ------ CPU registers, v/t, VRAM bus
    logic [7:0] bg_nt;
    logic [7:0] bg_lo;
    logic [1:0] bg_at;

    wire        status_rd   = !cpu_rw && (cpu_addr == PPUSTATUS);
    wire [14:0] v_step      = ppu_ctrl[CTRL_INC] ? 32 : 1;

    wire ppu_cs             = !ppu_cs_n;
    wire cpu_read           = cpu_rw && ppu_cs;
    wire cpu_write          = !cpu_rw && ppu_cs;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_addr       <= 0;
            t_addr       <= 0;
            fine_x       <= 0;
            read_buffer  <= 0;
            rd_cnt       <= 0;
            ppu_ctrl     <= 0;
            ppu_mask     <= 0;
            oam_addr     <= 0;
            write_toggle <= 1'b0;
            ppu_addr     <= 0;
            ppu_data_out <= 0;
            rd_n_q     <= 1'b1;
            wr_n_q     <= 1'b1;
            cpu_data_out <= 0;
            bg_nt        <= 0;
            bg_lo        <= 0;
            bg_at        <= 0;
        end else begin
            rd_n_q <= 1'b1;
            wr_n_q <= 1'b1;

            if (rd_cnt != 0) begin
                rd_cnt <= rd_cnt - 1;
                if (rd_cnt == 1) read_buffer <= bus_data_in;
            end

            if (rendering_active) begin
                // ---- scroll register maintenance
                if (cycle == 256)
                    v_addr <= inc_y(inc_x(v_addr));
                else if (tile_edge)
                    v_addr <= inc_x(v_addr);
                else if (cycle == 257) begin
                    v_addr[4:0] <= t_addr[4:0];
                    v_addr[10]  <= t_addr[10];
                end else if (prerender_line && cycle >= 280 && cycle <= 304) begin
                    v_addr[9:5]   <= t_addr[9:5];
                    v_addr[14:11] <= t_addr[14:11];
                end

                // ---- background fetches (8 dots per tile)
                if (bg_fetch_win) begin
                    case (mod8_cycle)
                        0: begin
                            ppu_addr <= 14'h2000 | {((tile_edge ? inc_x(v_addr) : v_addr) & 15'h0FFF)}[13:0];
                            rd_n_q <= 1'b0;
                        end
                        2: begin
                            bg_nt    <= bus_data_in;
                            ppu_addr <= {2'b10, v_addr[11:10], 4'b1111, v_addr[9:7], v_addr[4:2]};
                            rd_n_q <= 1'b0;
                        end
                        4: begin
                            bg_at    <= {(bus_data_in >> {v_addr[6], v_addr[1], 1'b0})}[1:0];
                            ppu_addr <= {1'b0, ppu_ctrl[CTRL_BG], bg_nt, 1'b0, v_addr[14:12]};
                            rd_n_q <= 1'b0;
                        end
                        6: begin
                            bg_lo    <= bus_data_in;
                            ppu_addr <= {1'b0, ppu_ctrl[CTRL_BG], bg_nt, 1'b1, v_addr[14:12]};
                            rd_n_q <= 1'b0;
                        end
                        default: ;
                    endcase
                end

                // ---- sprite pattern fetches (slot s at dots 256+8s .. 263+8s)
                if (spr_fetch_win) begin
                    if (mod8_cycle == 4) begin
                        ppu_addr <= spr_addr_lo;
                        rd_n_q <= 1'b0;
                    end else if (mod8_cycle == 6) begin
                        ppu_addr <= spr_addr_lo | 14'h0008;
                        rd_n_q <= 1'b0;
                    end
                end
            end

            // ---- CPU register access (wins over the render-side v updates)
            if (cpu_write) begin
                case (cpu_addr)
                    PPUCTRL: begin
                        ppu_ctrl      <= cpu_data_in;
                        t_addr[11:10] <= cpu_data_in[1:0];
                    end
                    PPUMASK: ppu_mask <= cpu_data_in;
                    OAMADDR: oam_addr <= cpu_data_in;
                    OAMDATA: begin
                        oam[oam_addr] <= cpu_data_in;
                        oam_addr      <= oam_addr + 1;
                    end
                    PPUSCROLL: begin
                        if (write_toggle) begin
                            t_addr[14:12] <= cpu_data_in[2:0];
                            t_addr[9:5]   <= cpu_data_in[7:3];
                        end else begin
                            t_addr[4:0] <= cpu_data_in[7:3];
                            fine_x      <= cpu_data_in[2:0];
                        end
                        write_toggle <= ~write_toggle;
                    end
                    PPUADDR: begin
                        if (write_toggle) begin
                            t_addr[7:0] <= cpu_data_in;
                            v_addr      <= {t_addr[14:8], cpu_data_in};
                        end else begin
                            t_addr[14:8] <= {1'b0, cpu_data_in[5:0]};
                        end
                        write_toggle <= ~write_toggle;
                    end
                    PPUDATA: begin
                        if (!rendering_active) begin
                            ppu_addr     <= v_addr[13:0];
                            ppu_data_out <= cpu_data_in;
                            wr_n_q       <= 1'b0;
                            v_addr       <= v_addr + v_step;
                        end
                    end
                    default: ;
                endcase
            end
            else if (cpu_read) begin
                case (cpu_addr)
                    PPUSTATUS: begin
                        write_toggle <= 1'b0;
                        cpu_data_out <= {vblank_flag, sprite0_hit_flag, sprite_overflow, 5'b00000};
                    end
                    OAMDATA: cpu_data_out <= oam[oam_addr];
                    PPUDATA: begin
                        cpu_data_out <= read_buffer;
                        if (!rendering_active) begin
                            ppu_addr <= v_addr[13:0];
                            rd_n_q <= 1'b0;
                            rd_cnt   <= 2;
                            v_addr   <= v_addr + v_step;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end
    

    // ------ background shifters
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
        end else if (rendering_active) begin
            if (bg_shift_win) begin
                pat_lo <= {pat_lo[14:0], 1'b0};
                pat_hi <= {pat_hi[14:0], 1'b0};
                att_lo <= {att_lo[14:0], 1'b0};
                att_hi <= {att_hi[14:0], 1'b0};
            end
            if (tile_edge) begin
                pat_lo[7:0] <= bg_lo;
                pat_hi[7:0] <= bus_data_in;
                att_lo[7:0] <= {8{bg_at[0]}};
                att_hi[7:0] <= {8{bg_at[1]}};
            end
        end
    end

    wire [3:0]      bsel        = 15 - {1'b0, fine_x};
    wire [3:0]      bg_pix      = {att_hi[bsel], att_lo[bsel], pat_hi[bsel], pat_lo[bsel]};

    // ------ sprite shifters
    logic [7:0]     spr_lo[0:7];
    logic [7:0]     spr_hi[0:7];
    logic [7:0]     spr_cnt[0:7];     // X delay counters
    logic [7:0]     spr_attr[0:7];
    logic [7:0]     spr_is0;
    wire [2:0]      cap_slot_hi = cycle[5:3] - 1;

    integer j;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 8; j = j + 1) begin
                spr_lo[j] <= 0;
                spr_hi[j] <= 0;
                spr_cnt[j] <= 0;
                spr_attr[j] <= 0;
            end
            spr_is0  <= 0;
        end else if (rendering_active) begin
            if (spr_fetch_win && mod8_cycle == 6) begin
                if (({1'b0, slot}) < spr_count) begin
                    spr_lo[slot]    <= cur_attr[6] ? reverse_byte(bus_data_in) : bus_data_in;
                    spr_cnt[slot]   <= sec_x[slot];
                    spr_attr[slot]  <= cur_attr;
                    spr_is0[slot]   <= sec_is0[slot];
                end else begin
                    spr_lo[slot] <= 0;
                end
            end else if (spr_cap_hi) begin
                if (({1'b0, cap_slot_hi}) < spr_count)
                    spr_hi[cap_slot_hi] <= sec_attr[cap_slot_hi][6] ? reverse_byte(bus_data_in) : bus_data_in;
                else
                    spr_hi[cap_slot_hi] <= 0;
            end else if (visible_pixel) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (spr_cnt[j] != 0) begin
                        spr_cnt[j] <= spr_cnt[j] - 1;
                    end else begin
                        spr_lo[j] <= {spr_lo[j][6:0], 1'b0};
                        spr_hi[j] <= {spr_hi[j][6:0], 1'b0};
                    end
                end
            end
        end
    end

    // ------ pixel mixer
    logic       spr_found;
    logic [3:0] spr_pix;       // {palette, color}
    logic       spr_behind;
    logic       spr0_opaque;

    always_comb begin
        integer i;
        spr_found   = 1'b0;
        spr_pix     = 0;
        spr_behind  = 1'b0;
        spr0_opaque = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (spr_cnt[i] == 0) begin
                if ({spr_hi[i][7], spr_lo[i][7]} != 2'b00) begin
                    if (spr_is0[i])
                        spr0_opaque = 1'b1;
                    if (!spr_found) begin
                        spr_found  = 1'b1;
                        spr_pix    = {spr_attr[i][1:0], spr_hi[i][7], spr_lo[i][7]};
                        spr_behind = spr_attr[i][5];
                    end
                end
            end
        end
    end

    
    wire left8          = (cycle <= 8);
    wire bg_en          = ppu_mask[MASK_BG_EN]  && !(left8 && !ppu_mask[MASK_8_BG_EN]);
    wire spr_en         = ppu_mask[MASK_SPR_EN] && !(left8 && !ppu_mask[MASK_8_SPR_EN]);
    wire bg_opaque      = bg_en  && (bg_pix[1:0] != 2'b00);
    wire spr_opaque     = spr_en && spr_found;

    always_comb begin
        video = 0;
        if (visible_pixel) begin
            if (bg_opaque && (!spr_opaque || spr_behind))
                video = {1'b0, bg_pix[3:0]};
            else if (spr_opaque)
                video = {1'b1, spr_pix};
        end
    end

    // Sprite 0 hit never triggers at x = 255 (cycle 256)
    assign sprite0_hit_now = visible_pixel && bg_opaque && spr_en && spr0_opaque &&
                             (cycle != 256);

    // ------ status flags / NMI
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vblank_flag      <= 1'b0;
            sprite0_hit_flag <= 1'b0;
            sprite_overflow  <= 1'b0;
        end else begin
            if (status_rd)
                vblank_flag <= 1'b0;
            if (ovf_pulse)
                sprite_overflow <= 1'b1;
            if (sprite0_hit_now)
                sprite0_hit_flag <= 1'b1;

            if (scanline == 241 && cycle == 1) begin
                vblank_flag <= 1'b1;
            end else if (prerender_line && cycle == 1) begin
                vblank_flag      <= 1'b0;
                sprite0_hit_flag <= 1'b0;
                sprite_overflow  <= 1'b0;
            end
        end
    end

    assign nmi_n = ~(ppu_ctrl[CTRL_NMI] & vblank_flag);

endmodule
