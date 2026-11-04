// NES PPU (2C02) - simplified, dot-based implementation.
//
// Conventions
//  * One `clk` = one PPU dot. `cycle` (0..340) / `scanline` (0..261, 261 = pre-render).
//  * CPU port: cpu_rw = 1 is a read, 0 is a write. Every access must be presented for
//    exactly one clk. Reads of $2000/$2001/$2003/$2005/$2006 and writes to $2002 are no-ops.
//  * The external VRAM bus (ppu_addr/ppu_data_out/ppu_rd_n/ppu_wr_n) is owned by
//    ppu_vram_bus. A read is two dots: address and ppu_rd_n = 0 are valid during the
//    first, memory answers on its edge, the PPU samples ppu_data_in at the end of the second.
//  * ce = 0 freezes every register of the PPU (pause); the bus outputs stay as they are.
//  * While rendering is active the bus belongs to the renderer; CPU accesses to $2007
//    are ignored then (real hardware glitches in that case).
//  * $2007 reads return the read buffer; palette reads are not forwarded immediately.
module ppu2C02
    import ppu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ce,            // one PPU dot; 0 pauses the whole PPU
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
    output logic [7:0]  pixel_color,
    output logic [8:0]  scanline,
    output logic [8:0]  cycle
);

    // ------ CPU registers
    logic [7:0]  ppu_ctrl;
    logic [7:0]  ppu_mask;
    logic [7:0]  oam_addr;
    ppu_cpu_strobe_t strobe;
    logic        vblank_flag, sprite0_hit_flag, sprite_overflow;
    logic [7:0]  oam_cpu_rdata;
    logic [7:0]  read_buffer;

    ppu_regs u_ppu_regs (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .ppu_cs_n(ppu_cs_n),
        .cpu_rw(cpu_rw),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        .vblank_flag(vblank_flag),
        .sprite0_hit_flag(sprite0_hit_flag),
        .sprite_overflow(sprite_overflow),
        .oam_rdata(oam_cpu_rdata),
        .read_buffer(read_buffer),
        .ppu_ctrl(ppu_ctrl),
        .ppu_mask(ppu_mask),
        .oam_addr(oam_addr),
        .strobe(strobe)
    );

    // ------ dot / line timing
    wire         rendering_enabled = ppu_mask[MASK_BG_EN] | ppu_mask[MASK_SPR_EN];
    ppu_timing_t timing;

    ppu_timing u_ppu_timing (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .rendering_enabled(rendering_enabled),
        .scanline(scanline),
        .cycle(cycle),
        .timing(timing)
    );

    // ------ scroll / VRAM address
    logic [14:0] v_addr;
    logic [2:0]  fine_x;

    ppu_scroll u_ppu_scroll (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .strobe(strobe),
        .increment_32(ppu_ctrl[CTRL_INC]),
        .cpu_data(cpu_data_in),
        .v_addr(v_addr),
        .fine_x(fine_x)
    );

    // ------ VRAM bus
    logic [13:0] spr_pat_addr;
    ppu_fetch_t  fetch;
    logic        palette_sel, palette_we;
    logic [7:0]  palette_rdata;

    ppu_vram_bus u_ppu_vram_bus (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .cycle(cycle),
        .v_addr(v_addr),
        .bg_pattern_table(ppu_ctrl[CTRL_BG]),
        .spr_pat_addr(spr_pat_addr),
        .strobe(strobe),
        .cpu_data(cpu_data_in),
        .read_buffer(read_buffer),
        .palette_sel(palette_sel),
        .palette_rdata(palette_rdata),
        .palette_we(palette_we),
        .ppu_addr(ppu_addr),
        .ppu_data_out(ppu_data_out),
        .ppu_data_in(ppu_data_in),
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(ppu_wr_n),
        .fetch(fetch)
    );

    // ------ OAM and sprite evaluation
    logic [5:0]  sprite_index;
    logic [7:0]  sprite_y, sprite_tile, sprite_attr, sprite_x;
    sprite_t     sec_oam  [0:7];
    logic [3:0]  spr_count;
    logic        ovf_pulse;

    ppu_oam u_ppu_oam (
        .clk(clk),
        .ce(ce),
        .cpu_we(strobe.oam_we),
        .cpu_addr(oam_addr),
        .cpu_wdata(cpu_data_in),
        .cpu_rdata(oam_cpu_rdata),
        .sprite_index(sprite_index),
        .sprite_y(sprite_y),
        .sprite_tile(sprite_tile),
        .sprite_attr(sprite_attr),
        .sprite_x(sprite_x)
    );

    ppu_sprite_eval u_ppu_sprite_eval (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .scanline(scanline),
        .rendering_enabled(rendering_enabled),
        .sprite_size_16(ppu_ctrl[CTRL_SP_SIZE]),
        .sprite_index(sprite_index),
        .sprite_y(sprite_y),
        .sprite_tile(sprite_tile),
        .sprite_attr(sprite_attr),
        .sprite_x(sprite_x),
        .sec_oam(sec_oam),
        .spr_count(spr_count),
        .ovf_pulse(ovf_pulse)
    );

    // ------ background
    logic [3:0]  bg_pix;

    ppu_bg_shifter u_ppu_bg_shifter (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .fetch(fetch),
        .fine_x(fine_x),
        .bg_pix(bg_pix)
    );

    // ------ sprites
    logic        spr_found;
    logic [3:0]  spr_pix;           // {palette, color}
    logic        spr_behind;
    logic        spr0_opaque;

    ppu_sprites u_ppu_sprites (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .scanline(scanline),
        .sprite_size_16(ppu_ctrl[CTRL_SP_SIZE]),
        .sprite_pattern_table(ppu_ctrl[CTRL_SP_PAT]),
        .sec_oam(sec_oam),
        .spr_count(spr_count),
        .fetch(fetch),
        .spr_pat_addr(spr_pat_addr),
        .spr_found(spr_found),
        .spr_pix(spr_pix),
        .spr_behind(spr_behind),
        .spr0_opaque(spr0_opaque)
    );

    // ------ pixel mixer
    logic [4:0]  video;             // palette index of the current pixel
    logic        sprite0_hit_now;

    ppu_mixer u_ppu_mixer (
        .timing(timing),
        .show_bg(ppu_mask[MASK_BG_EN]),
        .show_spr(ppu_mask[MASK_SPR_EN]),
        .show_bg_left8(ppu_mask[MASK_8_BG_EN]),
        .show_spr_left8(ppu_mask[MASK_8_SPR_EN]),
        .bg_pix(bg_pix),
        .spr_found(spr_found),
        .spr_pix(spr_pix),
        .spr_behind(spr_behind),
        .spr0_opaque(spr0_opaque),
        .video(video),
        .sprite0_hit_now(sprite0_hit_now)
    );

    // ------ palette: bus port and the colour of the current pixel
    ppu_palette u_ppu_palette (
        .clk(clk),
        .ce(ce),
        .addr(ppu_addr),
        .we(palette_we),
        .wdata(ppu_data_out),
        .sel(palette_sel),
        .rdata(palette_rdata),
        .pixel_index(video),
        .pixel_color(pixel_color)
    );

    // ------ status flags / NMI
    ppu_status u_ppu_status (
        .clk(clk),
        .rst_n(rst_n),
        .ce(ce),
        .timing(timing),
        .strobe(strobe),
        .ovf_pulse(ovf_pulse),
        .sprite0_hit_now(sprite0_hit_now),
        .nmi_enable(ppu_ctrl[CTRL_NMI]),
        .vblank_flag(vblank_flag),
        .sprite0_hit_flag(sprite0_hit_flag),
        .sprite_overflow(sprite_overflow),
        .nmi_n(nmi_n)
    );

    // PPUCTRL bits 1:0 (nametable select) go to t through wr_ctrl; bit 6 is unused on the NES
    wire unused = &{1'b0, ppu_ctrl[6], ppu_ctrl[1:0], ppu_mask[7:5], ppu_mask[0]};

endmodule
