`include "nes_sim.sv"
`include "cartridge/cartridge_sim.sv"
`include "joystick_sim.sv"
`include "utils/nes_video_capture.sv"

`define BMP_FILE "tb_200_color_test"

module tb_200_color_test;

    localparam integer FRAMES = 6;
    localparam integer FRAME_CLK = 341 * 262;

    logic clk;
    logic rst_n;
    logic running;          // capture starts once reset is released
    logic [1:0] phase;
    logic cpu_clk;
    logic [8:0] scanline;
    logic [8:0] cycle;
    logic [7:0] pixel_palette;
    logic [15:0] cpu_addr;
    logic cpu_undef;
    logic [15:0] cart_cpu_addr;
    logic [7:0]  cart_cpu_data_out;
    logic [7:0]  cart_cpu_data_in;
    logic        cart_cpu_rw;
    logic        cart_cpu_ce_n;
    logic [13:0] cart_ppu_addr;
    logic        cart_ppu_rd_n;
    logic        cart_ppu_wr_n;
    logic [7:0]  cart_ppu_data_out;
    logic [7:0]  cart_ppu_data_in;
    logic        cart_ciram_a10;
    logic        cart_ciram_ce_n;
    logic        cart_loaded;
    logic        cart_error;
    logic [7:0]  cart_error_code;
    logic        joy_strob;
    logic        joy1_oe_n;
    logic        joy2_oe_n;
    logic [7:0]  joy1_data;
    logic [7:0]  joy2_data;
    logic [3:0]  audio1;
    logic [3:0]  audio2;
    integer      audio_samples;
    integer i;

    always #5 clk = ~clk;

    // CPU clock = PPU clock / 3 (behavioral divider, initialized in the initial block)
    always @(posedge clk) begin
        phase   <= (phase == 2'd2) ? 2'd0 : phase + 2'd1;
        cpu_clk <= (phase == 2'd2);
    end

    nes_sim dut (
        .cpu_clk(cpu_clk),
        .ppu_clk(clk),
        .rst_n(rst_n),
        .scanline(scanline),
        .cycle(cycle),
        .pixel_palette(pixel_palette),
        .cart_cpu_addr(cart_cpu_addr),
        .cart_cpu_data_out(cart_cpu_data_out),
        .cart_cpu_data_in(cart_cpu_data_in),
        .cart_cpu_rw(cart_cpu_rw),
        .cart_cpu_ce_n(cart_cpu_ce_n),
        .cart_ppu_addr(cart_ppu_addr),
        .cart_ppu_rd_n(cart_ppu_rd_n),
        .cart_ppu_wr_n(cart_ppu_wr_n),
        .cart_ppu_data_out(cart_ppu_data_out),
        .cart_ppu_data_in(cart_ppu_data_in),
        .cart_ciram_a10(cart_ciram_a10),
        .cart_ciram_ce_n(cart_ciram_ce_n),
        .joy1_strob(joy_strob),
        .joy1_oe_n(joy1_oe_n),
        .joy1_data(joy1_data),
        .joy2_oe_n(joy2_oe_n),
        .joy2_data(joy2_data),
        .audio1(audio1),
        .audio2(audio2),
        .undef(cpu_undef)
    );

    // No buttons pressed on either pad
    joystick_sim u_joy1 (
        .strob(joy_strob),
        .oe_n(joy1_oe_n),
        .buttons(8'h00),
        .data(joy1_data)
    );

    joystick_sim u_joy2 (
        .strob(joy_strob),
        .oe_n(joy2_oe_n),
        .buttons(8'h00),
        .data(joy2_data)
    );

    cartridge_sim #
    (
        .ROM_FILE("../assets/color_test.nes")
    )
    u_cartridge (
        .clk(clk),
        .cpu_addr(cart_cpu_addr),
        .cpu_data_in(cart_cpu_data_out),
        .cpu_data_out(cart_cpu_data_in),
        .cpu_rw(cart_cpu_rw),
        .cpu_ce_n(cart_cpu_ce_n),
        .ppu_addr(cart_ppu_addr),
        .ppu_rd_n(cart_ppu_rd_n),
        .ppu_wr_n(cart_ppu_wr_n),
        .ppu_data_in(cart_ppu_data_out),
        .ppu_data_out(cart_ppu_data_in),
        .ciram_a10(cart_ciram_a10),
        .ciram_ce_n(cart_ciram_ce_n),
        .loaded(cart_loaded),
        .error(cart_error),
        .error_code(cart_error_code)
    );

    nes_video_capture #(
        .FRAMES(FRAMES),
        .BMP_BASE(`BMP_FILE)
    ) capture (
        .clk(clk),
        .enable(running),
        .scanline(scanline),
        .cycle(cycle),
        .palette_color(pixel_palette)
    );

    assign cpu_addr = dut.cpu_addr;

    initial begin
        $dumpfile("tb_200_color_test.vcd");
        $dumpvars(0, tb_200_color_test);
        clk = 1'b0;
        phase = 2'd0;
        cpu_clk = 1'b0;
        running = 1'b0;
        audio_samples = 0;

        #1;
        if (cart_error || !cart_loaded)
            $fatal(1, "tb_200_color_test: cartridge not loaded, error code %02h", cart_error_code);

        for (i = 0; i < 2048; i = i + 1) begin
            dut.u_cpu_ram.data[i] = 8'h00;
            dut.u_ciram.data[i] = 8'h00;
        end
        for (i = 0; i < 32; i = i + 1)
            dut.u_ppu.u_palette_ram.data[i] = 8'h0F;

        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        #1 rst_n = 1'b1;
        running = 1'b1;
    end

    // Audio is not checked, only reported: count CPU clocks with sound
    always @(posedge clk)
        if (cpu_clk && (audio1 != 0 || audio2 != 0))
            audio_samples <= audio_samples + 1;

    final
        $display("tb_200_color_test: %0d CPU clocks with audio output", audio_samples);

    always @(posedge clk) begin
        if (cpu_undef === 1'b1)
            $fatal(1, "tb_200_color_test: undefined opcode at %04h", cpu_addr);
    end

    initial begin
        #1;
        repeat ((FRAMES + 4) * FRAME_CLK) @(posedge clk);
        $fatal(1, "tb_200_color_test: timeout before %0d frames completed", FRAMES);
    end

endmodule
