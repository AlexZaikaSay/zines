`timescale 1ns/1ps

// The whole console in simulation: zines_system with the OSD firmware, an SD
// card image and SDL for the picture, sound and keyboard pads. Pick a game in the
// OSD menu; the firmware loads it from the card and starts the NES.
// One clock drives the NES, the supervisor and the display here. A display frame
// (800x525) is ~4.7 NES frames long at the same clock, so the window has two layers:
// the game straight from the PPU (every NES frame, like `video`), and the OSD taken
// from the display chain, refreshed once per display frame.
module zines (
    input logic clk
);
    parameter string OSD_ROM_FILE = "./data/osd.tv";
    parameter string FONT_FILE    = "./data/font.hex";
    parameter string SD_FILE      = "./data/sd.img";

    // clk is driven by utils/sim_main.cpp; reset is held for 50 clocks.
    logic [7:0] rst_cnt = 8'd0;
    logic       rst_n;
    always @(posedge clk)
        if (rst_cnt != 8'd50) rst_cnt <= rst_cnt + 8'd1;
    assign rst_n = (rst_cnt == 8'd50);

    logic [7:0] pad_buttons = 8'h00;
    logic       sd_clk, sd_cmd, sd_dat0, sd_cs_n;
    logic [9:0] disp_h, disp_v;
    logic       disp_image;
    logic [5:0] disp_index;
    logic       cpu_ce;
    logic [3:0] audio1, audio2, audio3, audio4;
    logic       nes_running, nes_undef, sup_undef;

    zines_system #(
        .OSD_ROM_FILE(OSD_ROM_FILE),
        .FONT_FILE(FONT_FILE)
    ) u_sys (
        .clk(clk),
        .rst_n(rst_n),
        .pix_clk(clk),
        .pix_rst_n(rst_n),
        .pad1_buttons(pad_buttons),
        .pad2_buttons(8'h00),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(1'b0),
        .disp_h(disp_h),
        .disp_v(disp_v),
        .disp_image(disp_image),
        .disp_index(disp_index),
        .disp_hsync(),
        .disp_vsync(),
        .cpu_ce(cpu_ce),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4),
        .nes_running(nes_running),
        .nes_undef(nes_undef),
        .sup_undef(sup_undef)
    );

    sim_sd_card #(
        .SD_FILE(SD_FILE)
    ) u_sd_card (
        .clk(clk),
        .rst_n(rst_n),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_cs_n(sd_cs_n),
        .sd_dat0(sd_dat0)
    );

    // Power-on contents the hardware would have (block RAM init)
    initial begin
        for (int i = 0; i < 2048; i++) begin
            u_sys.u_nes.u_cpu_ram.data[i] = 8'h00;
            u_sys.u_nes.u_ciram.data[i]   = 8'h00;
            u_sys.u_osd.text[i]           = 8'h20;
            u_sys.u_osd.attr[i]           = 8'h00;
        end
        for (int i = 0; i < 32; i++)
            u_sys.u_nes.u_ppu.u_ppu_palette.data[i] = 8'h0F;
        for (int i = 0; i < 65536; i++)
            u_sys.u_frame_buffer.mem[i] = 6'h0F;
    end

    import "DPI-C" function void sdl_display_init(input string title);
    import "DPI-C" function void sdl_display_pixel(input int x, input int y, input int palette_index);
    import "DPI-C" function int  sdl_display_present();
    import "DPI-C" function void sdl_display_close();
    import "DPI-C" function int  sdl_display_buttons();
    import "DPI-C" function void sdl_audio_init();
    import "DPI-C" function void sdl_audio_sample(input int audio1, input int audio2, input int audio3, input int audio4);
    import "DPI-C" function void sdl_audio_close();

    initial sdl_audio_init();
    initial sdl_display_init("zines");

    import "DPI-C" function void sdl_display_osd_pixel(input int x, input int y, input int palette_index);

    // Game layer: the PPU pixels as they go into the frame buffer
    wire       nes_pix   = u_sys.pix_valid;
    wire [7:0] nes_x     = u_sys.pix_x;
    wire [7:0] nes_y     = u_sys.pix_y;
    wire [5:0] nes_index = u_sys.pixel_palette[5:0];
    wire       nes_frame_end = nes_pix && nes_x == 8'd255 && nes_y == 8'd239;

    // OSD layer: the glyph pixel of the display chain (0 = transparent), aligned
    // with disp_h / disp_v; one display pixel of each 2x2 block
    wire [9:0] pic_x     = disp_h - 10'd64;
    wire       pic_pixel = disp_image && !pic_x[0] && !disp_v[0];
    wire [7:0] osd_pixel = u_sys.u_osd.osd_pixel;

    // The window is shown and the keyboard read once per NES frame, or once per
    // display frame while the NES is held in reset (menu only)
    wire disp_frame_end = disp_v == 10'd480 && disp_h == 10'd0;
    wire frame_end      = nes_running ? nes_frame_end : disp_frame_end;

    // W,S,A,D = Up, Down, Left, Right, right arrow = A, down arrow = B, Enter = Start
    always @(posedge clk)
        if (frame_end)
            pad_buttons <= 8'(sdl_display_buttons());

    always @(posedge clk) begin
        if (rst_n) begin
            if (nes_pix)
                sdl_display_pixel(int'(nes_x), int'(nes_y),
                                  (^nes_index === 1'bx) ? 0 : int'(nes_index));
            if (pic_pixel)
                sdl_display_osd_pixel(int'(pic_x[8:1]), int'(disp_v[8:1]),
                                      (^osd_pixel === 1'bx) ? 0 : int'(osd_pixel[5:0]));

            // Once per NES CPU cycle, the rate the SDL audio side expects; silent in the menu
            if (cpu_ce)
                sdl_audio_sample((^audio1 === 1'bx) ? 0 : int'(audio1),
                                 (^audio2 === 1'bx) ? 0 : int'(audio2),
                                 (^audio3 === 1'bx) ? 0 : int'(audio3),
                                 (^audio4 === 1'bx) ? 0 : int'(audio4));

            if (frame_end && sdl_display_present() != 0) begin
                sdl_audio_close();
                sdl_display_close();
                $finish;
            end
        end
    end

    // Report when the firmware starts the game
    logic running_q = 1'b0;
    always @(posedge clk) begin
        running_q <= nes_running;
        if (nes_running && !running_q)
            $display("zines: NES started at %0t", $time);
    end

    always @(posedge clk) begin
        if (sup_undef === 1'b1)
            $fatal(1, "zines: supervisor undefined opcode at %04h", u_sys.u_supervisor.cpu_addr);
        if (nes_running && nes_undef === 1'b1)
            $fatal(1, "zines: NES undefined opcode at %04h", u_sys.u_nes.cpu_addr);
    end

endmodule
