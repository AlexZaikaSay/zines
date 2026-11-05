// The whole console: NES core + cartridge slot + supervisor (OSD CPU) + display.
//
//   supervisor -- fill port --> cartridge <-- cart edge --> nes
//       |  NES_CTRL reset / pause ---------------------------^
//       |  OSD text ----> osd_overlay
//   nes -- pixels --> frame_buffer --> nes_scaler --> osd_overlay --> display raster
//
// clk runs the NES (one clk = one PPU dot) and the cartridge, sup_clk the
// supervisor, pix_clk the display. sup_clk must be clk itself (same edges): the
// supervisor's outputs (NES_CTRL, the fill port) are used in the clk domain with
// no synchronisers. It is a separate port so a simulation can stop the supervisor
// while the game runs (a stopped clock saves simulation time, ce = 0 does not). The board adds the output stage (video_out / HDMI).
// The NES stays in reset until the firmware has loaded a game and cleared
// NES_CTRL_RESET; NES_CTRL_PAUSE freezes it, the display keeps the last frame.
module zines_system #(
    parameter OSD_ROM_FILE = "",                // firmware image ($8000-$FFFF)
    parameter FONT_FILE = "font.hex",
    parameter integer CLK_FREQ_HZ = 50_000_000  // clk, for the SD SPI timing
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        sup_clk,                // = clk on a board
    input  logic        pix_clk,
    input  logic        pix_rst_n,

    input  logic [7:0]  pad1_buttons,           // A, B, Select, Start, Up, Down, Left, Right; 1 = pressed
    input  logic [7:0]  pad2_buttons,

    // SD card SPI
    output logic        sd_clk,
    output logic        sd_cmd,
    input  logic        sd_dat0,
    output logic        sd_cs_n,
    input  logic        sd_cd_n,

    // display raster (pix_clk): position, picture with the OSD on top
    output logic [9:0]  disp_h,
    output logic [9:0]  disp_v,
    output logic        disp_image,             // disp_index is a picture pixel; black otherwise
    output logic [5:0]  disp_index,
    output logic        disp_hsync,             // active high
    output logic        disp_vsync,

    // audio (clk)
    output logic        cpu_ce,                 // one NES CPU cycle
    output logic [3:0]  audio1,
    output logic [3:0]  audio2,
    output logic [3:0]  audio3,
    output logic [3:0]  audio4,

    output logic        nes_running,            // out of reset and not paused
    output logic        nes_undef,              // simulation: undefined opcode
    output logic        sup_undef
);

    import zines_pkg::*;

    // ------ supervisor
    logic        nes_reset, nes_pause;
    logic [2:0]  fill_w;
    logic [14:0] init_addr;
    logic [7:0]  init_data;
    logic        osd_text_we, osd_attr_we;
    logic [10:0] osd_waddr;
    logic [7:0]  osd_wdata;

    supervisor #(
        .ROM_FILE(OSD_ROM_FILE),
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) u_supervisor (
        .clk(sup_clk),
        .rst_n(rst_n),
        .pad_buttons(pad1_buttons),
        .nes_reset(nes_reset),
        .nes_pause(nes_pause),
        .fill_w(fill_w),
        .init_addr(init_addr),
        .init_data(init_data),
        .osd_text_we(osd_text_we),
        .osd_attr_we(osd_attr_we),
        .osd_waddr(osd_waddr),
        .osd_wdata(osd_wdata),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd_n),
        .undef(sup_undef)
    );

    // ------ NES core
    logic nes_rst_n;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            nes_rst_n <= 1'b0;
        else
            nes_rst_n <= !nes_reset;
    end

    wire run = !nes_pause;
    assign nes_running = nes_rst_n && run;

    clock_enable_gen u_clock_enable_gen (
        .clk(clk),
        .rst_n(nes_rst_n),
        .ce(run),
        .cpu_ce(cpu_ce)
    );

    logic [8:0]  nes_scanline, nes_cycle;     // pixel position comes as pix_x / pix_y
    logic [7:0]  pixel_palette;
    logic        pix_valid;
    logic [7:0]  pix_x, pix_y;
    logic        joy_strobe, joy1_oe_n, joy2_oe_n, joy1_d, joy2_d;
    logic [15:0] cart_cpu_addr;
    logic [7:0]  cart_cpu_data;
    logic        cart_cpu_rw, cart_cpu_ce_n;
    logic [13:0] cart_ppu_addr;
    logic        cart_ppu_rd_n, cart_ppu_wr_n;
    logic [7:0]  cart_ppu_wdata, cart_ppu_rdata;
    logic        cart_ciram_a10, cart_ciram_ce_n;

    nes u_nes (
        .ppu_clk(clk),
        .rst_n(nes_rst_n),
        .cpu_ce(cpu_ce),
        .ppu_ce(run),
        .scanline(nes_scanline),
        .cycle(nes_cycle),
        .pixel_palette(pixel_palette),
        .pix_valid(pix_valid),
        .pix_x(pix_x),
        .pix_y(pix_y),
        .joy1_strob(joy_strobe),
        .joy1_oe_n(joy1_oe_n),
        .joy1_data({7'd0, joy1_d}),
        .joy2_oe_n(joy2_oe_n),
        .joy2_data({7'd0, joy2_d}),
        .cart_cpu_addr(cart_cpu_addr),
        .cart_cpu_data_in(cart_cpu_data),
        .cart_cpu_rw(cart_cpu_rw),
        .cart_cpu_ce_n(cart_cpu_ce_n),
        .cart_ppu_addr(cart_ppu_addr),
        .cart_ppu_rd_n(cart_ppu_rd_n),
        .cart_ppu_wr_n(cart_ppu_wr_n),
        .cart_ppu_data_out(cart_ppu_wdata),
        .cart_ppu_data_in(cart_ppu_rdata),
        .cart_ciram_a10(cart_ciram_a10),
        .cart_ciram_ce_n(cart_ciram_ce_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4),
        .undef(nes_undef)
    );

    nes_pad_port u_pad1 (
        .clk(clk),
        .rst_n(nes_rst_n),
        .strobe(joy_strobe),
        .oe_n(joy1_oe_n),
        .buttons(pad1_buttons),
        .data(joy1_d)
    );

    nes_pad_port u_pad2 (
        .clk(clk),
        .rst_n(nes_rst_n),
        .strobe(joy_strobe),
        .oe_n(joy2_oe_n),
        .buttons(pad2_buttons),
        .data(joy2_d)
    );

    // ------ cartridge slot, filled by the supervisor
    cartridge u_cartridge (
        .clk(clk),
        .cpu_addr(cart_cpu_addr),
        .cpu_data_out(cart_cpu_data),
        .cpu_rw(cart_cpu_rw),
        .cpu_ce_n(cart_cpu_ce_n),
        .ppu_addr(cart_ppu_addr),
        .ppu_rd_n(cart_ppu_rd_n),
        .ppu_wr_n(cart_ppu_wr_n),
        .ppu_data_in(cart_ppu_wdata),
        .ppu_data_out(cart_ppu_rdata),
        .ciram_a10(cart_ciram_a10),
        .ciram_ce_n(cart_ciram_ce_n),
        .fill_w(fill_w),
        .init_data_in(init_data),
        .init_addr(init_addr)
    );

    // ------ display
    logic [9:0] raster_h, raster_v;
    logic       raster_de, raster_hs, raster_vs;
    logic [7:0] fb_rx, fb_ry;
    logic [5:0] fb_index;
    logic [9:0] img_h, img_v;
    logic       img_image, img_hs, img_vs;

    video_timing_gen u_timing (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .h(raster_h),
        .v(raster_v),
        .de(raster_de),
        .hsync(raster_hs),
        .vsync(raster_vs)
    );

    nes_scaler u_scaler (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .h(raster_h),
        .v(raster_v),
        .de(raster_de),
        .hsync(raster_hs),
        .vsync(raster_vs),
        .rx(fb_rx),
        .ry(fb_ry),
        .h_q(img_h),
        .v_q(img_v),
        .image_q(img_image),
        .hsync_q(img_hs),
        .vsync_q(img_vs)
    );

    frame_buffer u_frame_buffer (
        .wclk(sup_clk),
        .we(pix_valid),
        .wx(pix_x),
        .wy(pix_y),
        .wdata(pixel_palette[5:0]),
        .rclk(pix_clk),
        .rx(fb_rx),
        .ry(fb_ry),
        .rdata(fb_index)
    );

    osd_overlay #(
        .FONT_FILE(FONT_FILE)
    ) u_osd (
        .clk(pix_clk),
        .rst_n(pix_rst_n),
        .wclk(clk),
        .text_we(osd_text_we),
        .attr_we(osd_attr_we),
        .waddr(osd_waddr),
        .wdata(osd_wdata),
        .h(raster_h),
        .v(raster_v),
        .h1(img_h),
        .v1(img_v),
        .image1(img_image),
        .hsync1(img_hs),
        .vsync1(img_vs),
        .index1(fb_index),
        .h2(disp_h),
        .v2(disp_v),
        .image2(disp_image),
        .hsync2(disp_hsync),
        .vsync2(disp_vsync),
        .index2(disp_index)
    );

    wire unused = &{1'b0, pixel_palette[7:6], nes_scanline, nes_cycle};

endmodule
