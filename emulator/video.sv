`include "nes.sv"
`include "cartridge/cartridge.sv"
`include "cartridge/cartridge_loader.sv"
`include "joystick/joystick_sim.sv"

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

    // The NES stays in reset until the cartridge is loaded from the file
    logic cart_loaded;
    wire  nes_rst_n = rst_n && cart_loaded;

    always_ff @(posedge clk) begin
        phase   <= (phase == 2'd2) ? 2'd0 : phase + 2'd1;
        cpu_clk <= (phase == 2'd2);
    end

    nes dut (
        .cpu_clk(cpu_clk),
        .ppu_clk(clk),
        .rst_n(nes_rst_n),
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

    // Cartridge: cartridge_file_loader streams the iNES file into
    // cartridge_new after reset
    logic        cart_set_w, cart_prg_w, cart_chr_w;
    logic [7:0]  cart_prg_banks, cart_chr_banks;
    logic        cart_vertical;
    logic [14:0] cart_init_addr;
    logic [7:0]  cart_init_data;
    logic        cart_error;
    logic [7:0]  cart_error_code;

    cartridge_loader #(
        .ROM_FILE("../assets/SMB.nes")
    ) u_cart_loader (
        .clk(clk),
        .rst_n(rst_n),
        .set_w(cart_set_w),
        .prg_w(cart_prg_w),
        .chr_w(cart_chr_w),
        .prg_banks(cart_prg_banks),
        .chr_banks(cart_chr_banks),
        .vertical(cart_vertical),
        .init_addr(cart_init_addr),
        .init_data(cart_init_data),
        .done(cart_loaded),
        .error(cart_error),
        .error_code(cart_error_code)
    );

    cartridge u_cartridge (
        .clk(clk),
        .cpu_addr(cart_cpu_addr),
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
        .set_w(cart_set_w),
        .prg_w(cart_prg_w),
        .chr_w(cart_chr_w),
        .vertical(cart_vertical),
        .prg_banks(cart_prg_banks),
        .chr_banks(cart_chr_banks),
        .init_data_in(cart_init_data),
        .init_addr(cart_init_addr)
    );

    always @(posedge clk)
        if (cart_error)
            $fatal(1, "video: cartridge load failed, error %02h", cart_error_code);

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

    // Gamepad simulation, W,S,A,D = Up, Down, Left, Right, right arrow = A, down arrow = B, Enter = Start
    always @(posedge clk or negedge rst_n) begin
        if (rst_n === 1'b1) begin
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
            $fatal(1, "video: undefined opcode at %04h", cpu_addr);
    end

endmodule
