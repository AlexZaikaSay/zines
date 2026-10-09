`include "nes_sim.sv"
`include "cartridge/cartridge_sim.sv"
`include "utils/nes_video_capture.sv"

`define BMP_FILE "tb_200_color_test"

module tb_200_color_test;

    localparam integer FRAMES = 6;
    localparam integer FRAME_CLK = 341 * 262;

    logic clk = 1'b0;
    logic rst_n;
    logic [1:0] phase = 2'd0;
    logic cpu_clk = 1'b0;
    logic [8:0] scanline;
    logic [8:0] cycle;
    logic [4:0] video;
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
        .video(video),
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
        .cart_ciram_ce_n(cart_ciram_ce_n)
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
        .loaded(),
        .error(),
        .error_code()
    );

    nes_video_capture #(
        .FRAMES(FRAMES),
        .BMP_BASE(`BMP_FILE)
    ) capture (
        .clk(clk),
        .rst_n(rst_n),
        .scanline(scanline),
        .cycle(cycle),
        .palette_color(pixel_palette)
    );

    assign cpu_addr = dut.cpu_addr;
    assign cpu_undef = dut.cpu_undef;

    initial begin
        $dumpfile("tb_200_color_test.vcd");
        $dumpvars(0, tb_200_color_test);

        for (i = 0; i < 2048; i = i + 1) begin
            dut.u_cpu_ram.data[i] = 8'h00;
            dut.u_ciram.data[i] = 8'h00;
        end
        for (i = 0; i < 32; i = i + 1)
            dut.u_ppu.u_palette_ram.data[i] = 8'h0F;

        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        #1 rst_n = 1'b1;
    end

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
