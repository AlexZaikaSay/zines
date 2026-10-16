`include "nes_sim.sv"
`include "cartridge/cartridge_sim.sv"
`include "joystick_sim.sv"

`timescale 1ns/1ps

module video (
    input logic clk
);
    logic rst_n;
    logic [1:0] phase;
    logic cpu_clk;
    logic [8:0] scanline;
    logic [8:0] cycle;
    logic [7:0] pixel_palette;
    logic       joy1_strob;
    logic       joy1_oe_n;
    logic [7:0] joy1_data;
    logic       joy2_oe_n;
    logic [7:0] joy2_data;
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
    logic [3:0]  audio1;
    logic [3:0]  audio2;
    logic [3:0]  audio3;
    logic [3:0]  audio4;
    integer i;

    // clk is driven by utils/sim_main.cpp; reset is held for 50 clocks.
    logic [7:0] rst_cnt = 8'd0;
    always @(posedge clk)
        if (rst_cnt != 8'd50) rst_cnt <= rst_cnt + 8'd1;
    assign rst_n = (rst_cnt == 8'd50);

    always_ff @(posedge clk) begin
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
        .joy1_strob(joy1_strob),
        .joy1_oe_n(joy1_oe_n),
        .joy1_data(joy1_data),
        .joy2_oe_n(joy2_oe_n),
        .joy2_data(joy2_data),
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
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4),
        .undef(cpu_undef)
    );

    cartridge_sim #
    (
        .ROM_FILE("../assets/SMB.nes")
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
        .loaded(),
        .error(),
        .error_code()
    );

    logic [7:0] pad_buttons = 8'h00;

    joystick_sim u_joystick (
        .strob(joy1_strob),
        .oe_n(joy1_oe_n),
        .buttons(pad_buttons),
        .data(joy1_data)
    );

    // Second pad is plugged in but never pressed
    joystick_sim u_joystick2 (
        .strob(joy1_strob),
        .oe_n(joy2_oe_n),
        .buttons(8'h00),
        .data(joy2_data)
    );

    assign cpu_addr = dut.cpu_addr;

    initial begin
        // $dumpfile("video.vcd");
        // $dumpvars(0, video);
        
        for (i = 0; i < 2048; i = i + 1) begin
            dut.u_cpu_ram.data[i] = 8'h00;
            dut.u_ciram.data[i] = 8'h00;
        end
        for (i = 0; i < 32; i = i + 1)
            dut.u_ppu.u_palette_ram.data[i] = 8'h0F;
    end

    import "DPI-C" function void sdl_display_init(input string title);
    import "DPI-C" function void sdl_display_pixel(input int x, input int y, input int palette_index);
    import "DPI-C" function int  sdl_display_present();
    import "DPI-C" function void sdl_display_close();
    import "DPI-C" function int  sdl_display_buttons();
    import "DPI-C" function void sdl_audio_init();
    import "DPI-C" function void sdl_audio_sample(input int audio1, input int audio2, input int audio3, input int audio4);
    import "DPI-C" function void sdl_audio_close();

    // Keyboard state sampled once per frame: A, B, Select, Start, Up, Down, Left, Right
    always @(posedge clk)
        if (scanline == 240 && cycle == 0) begin
            pad_buttons <= 8'(sdl_display_buttons());
        end

    initial sdl_audio_init();
    initial sdl_display_init("zines NES");

    // Same sampling as nes_video_capture: visible area is scanlines 0-239, dots 1-256.
    // Gamepad simulation, W,S,A,D = Up, Down, Left, Right, right arrow = A, down arrow = B, Enter = Start
    always @(posedge clk or negedge rst_n) begin
        if (rst_n === 1'b1) begin
            // if (dut.u_cpu.core_write_apu_status)
            //     $display("apu[%04h] = %02h", dut.u_cpu.core_addr, dut.u_cpu.apu_data_in);

            // if (dut.u_cpu.core_write_apu && dut.u_cpu.core_addr == 16'h4008 /* && (dut.u_cpu.u_apu.data_in[4] == 1'b1) */)
            //     $display("apu[%04h] = %02h", dut.u_cpu.u_apu.addr, dut.u_cpu.u_apu.data_in);
            if (scanline < 240 && cycle >= 1 && cycle <= 256)
                sdl_display_pixel(int'(cycle) - 1, int'(scanline),
                                  (^pixel_palette === 1'bx) ? 0 : int'(pixel_palette[5:0]));

            // Once per CPU clock (PPU clk / 3), the rate the SDL audio side expects.
            if (cpu_clk)
                sdl_audio_sample((^audio1 === 1'bx) ? 0 : int'(audio1),
                                 (^audio2 === 1'bx) ? 0 : int'(audio2),
                                 (^audio3 === 1'bx) ? 0 : int'(audio3),
                                 (^audio4 === 1'bx) ? 0 : int'(audio4));

            if (scanline == 240 && cycle == 0) begin
                if (sdl_display_present() != 0) begin
                    sdl_audio_close();
                    sdl_display_close();
                    $finish;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (cpu_undef === 1'b1)
            $fatal(1, "tb_201_video: undefined opcode at %04h", cpu_addr);
    end

endmodule
