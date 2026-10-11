`include "nes_sim.sv"
`include "cartridge/cartridge_sim.sv"

module tb_201_video;
    logic rst_n;
    logic [1:0] phase;
    logic clk;
    logic cpu_clk;
    logic [8:0] scanline;
    logic [8:0] cycle;
    logic [7:0] pixel_palette;
    logic       joy1_strob;
    logic       joy1_oe_n;
    logic [7:0] joy1_data;
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
    integer i;

    always #5 clk = ~clk;

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
        .video(),
        .pixel_palette(pixel_palette),
        .joy1_strob(joy1_strob),
        .joy1_oe_n(joy1_oe_n),
        .joy1_data(joy1_data),
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
        .cart_ciram_ce_n(cart_ciram_ce_n)
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

    assign cpu_addr = dut.cpu_addr;
    assign cpu_undef = dut.cpu_undef;

    initial begin
        // $dumpfile("tb_201_video.vcd");
        // $dumpvars(0, tb_201_video);
        
        clk = 1'b0;
        for (i = 0; i < 2048; i = i + 1) begin
            dut.u_cpu_ram.data[i] = 8'h00;
            dut.u_ciram.data[i] = 8'h00;
        end
        for (i = 0; i < 32; i = i + 1)
            dut.u_ppu.u_palette_ram.data[i] = 8'h0F;

        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
    end

    import "DPI-C" function void sdl_display_init(input string title);
    import "DPI-C" function void sdl_display_pixel(input int x, input int y, input int palette_index);
    import "DPI-C" function int  sdl_display_present();
    import "DPI-C" function void sdl_display_close();
    import "DPI-C" function int  sdl_display_buttons();

    // Keyboard state sampled once per frame: A, B, Select, Start, Up, Down, Left, Right
    always @(posedge clk)
        if (scanline == 240 && cycle == 0) begin
            pad_buttons <= 8'(sdl_display_buttons());
        end

    initial sdl_display_init("zines NES");

    // Same sampling as nes_video_capture: visible area is scanlines 0-239, dots 1-256.
    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (scanline < 240 && cycle >= 1 && cycle <= 256)
                sdl_display_pixel(int'(cycle) - 1, int'(scanline),
                                  (^pixel_palette === 1'bx) ? 0 : int'(pixel_palette[5:0]));

            if (scanline == 240 && cycle == 0) begin
                if (sdl_display_present() != 0) begin
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
