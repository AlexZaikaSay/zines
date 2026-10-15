`include "cpu/cpu2A03.sv"
`include "cpu/mem.sv"
`include "ppu/ppu2C02.sv"

module nes_sim (
    input  logic       cpu_clk,
    input  logic       ppu_clk,
    input  logic       rst_n,
    output logic [8:0] scanline,
    output logic [8:0] cycle,
    output logic [7:0] pixel_palette,

    // Joystick interface: strobe is shared by both ports
    output logic       joy1_strob,
    output logic       joy1_oe_n,
    input  logic [7:0] joy1_data,
    output logic       joy2_oe_n,
    input  logic [7:0] joy2_data,

    // Cartridge edge connector
    output logic [15:0] cart_cpu_addr,
    output logic [7:0]  cart_cpu_data_out,
    input  logic [7:0]  cart_cpu_data_in,
    output logic        cart_cpu_rw,
    output logic        cart_cpu_ce_n,
    output logic [13:0] cart_ppu_addr,
    output logic        cart_ppu_rd_n,
    output logic        cart_ppu_wr_n,
    output logic [7:0]  cart_ppu_data_out,
    input  logic [7:0]  cart_ppu_data_in,
    input  logic        cart_ciram_a10,
    input  logic        cart_ciram_ce_n,

    // Audio outputs
    output logic [3:0] audio1,
    output logic [3:0] audio2,
    output logic [3:0] audio3,
    output logic [3:0] audio4,

    // Simulation status: CPU fetched an undefined opcode
    output logic       undef
);

    logic        nmi_n;
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_data_out;
    logic [7:0]  cpu_data_in;
    logic        cpu_rw;
    logic        cpu_strobe;
    logic [7:0]  cpu_ram_data;
    logic [7:0]  ppu_cpu_data;

    // CPU address decoding
    wire cpu_ram_selected      = cpu_addr[15:13] == 3'b000;    // $0000-$1FFF
    wire ppu_register_selected = cpu_addr[15:13] == 3'b001;    // $2000-$3FFF
    wire cartridge_selected    = cpu_addr[15];                 // $8000-$FFFF
    wire ppu_register_access = cpu_strobe && ppu_register_selected;

    always_ff @(posedge ppu_clk or negedge rst_n) begin
        if (!rst_n)
            cpu_strobe <= 1'b0;
        else
            cpu_strobe <= cpu_clk;
    end

    cpu2A03 u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n),
        .irq_n(1'b1),
        .data_in(cpu_data_in),
        .data_out(cpu_data_out),
        .addr(cpu_addr),
        .rw(cpu_rw),
        .out0(joy1_strob),
        .oe1_n(joy1_oe_n),
        .oe2_n(joy2_oe_n),
        .audio1(audio1),
        .audio2(audio2),
        .audio3(audio3),
        .audio4(audio4),
        .undef(undef)
    );

    mem #(
        .ADDR_WIDTH(11)
    ) u_cpu_ram (
        .clk(cpu_clk),
        .addr(cpu_addr[10:0]),
        .data_in(cpu_data_out),
        .data_out(cpu_ram_data),
        .rw(cpu_rw),
        .cs_n(!cpu_ram_selected),
        .oe_n(!cpu_rw)
    );

    always_comb begin
        if (!joy1_oe_n)
            cpu_data_in = joy1_data;
        else if (!joy2_oe_n)
            cpu_data_in = joy2_data;
        else if (cartridge_selected)
            cpu_data_in = cart_cpu_data_in;
        else if (cpu_ram_selected)
            cpu_data_in = cpu_ram_data;
        else if (ppu_register_selected)
            cpu_data_in = ppu_cpu_data;
        else
            cpu_data_in = 8'h00;
    end

    logic [13:0] ppu_addr;
    logic [7:0]  ppu_data_out;
    wire  [7:0]  ppu_data;
    wire  [7:0]  ciram_raw;
    logic [7:0]  ciram_data;      // registered like cartridge CHR: the PPU samples a clock after rd_n
    logic        ppu_rd_n;
    logic        ppu_wr_n;

    ppu2C02 u_ppu (
        .clk(ppu_clk),
        .rst_n(rst_n),
        .ppu_cs_n(!ppu_register_access),
        .cpu_rw(cpu_rw),
        .cpu_addr(cpu_addr[2:0]),
        .cpu_data_in(cpu_data_out),
        .ppu_data_in(ppu_data),
        .cpu_data_out(ppu_cpu_data),
        .ppu_addr(ppu_addr),
        .ppu_data_out(ppu_data_out),
        .nmi_n(nmi_n),
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(ppu_wr_n),
        .pixel_color(pixel_palette)
    );

    assign scanline = u_ppu.scanline;
    assign cycle = u_ppu.cycle;

    assign cart_cpu_addr     = cpu_addr;
    assign cart_cpu_data_out = cpu_data_out;
    assign cart_cpu_rw       = cpu_rw;
    assign cart_cpu_ce_n     = !cartridge_selected;
    assign cart_ppu_addr     = ppu_addr;
    assign cart_ppu_rd_n     = ppu_rd_n;
    assign cart_ppu_wr_n     = ppu_wr_n;
    assign cart_ppu_data_out = ppu_data_out;

    // PPU drives the bus on writes, the cartridge CHR drives it while A13 is low
    // Resolved with a mux: Verilator is 2-state and cannot resolve multiple 'z' drivers
    assign ppu_data = !ppu_wr_n          ? ppu_data_out :
                      !cart_ciram_ce_n   ? ciram_data   :
                                           cart_ppu_data_in;

    always_ff @(posedge ppu_clk) begin
        if (!cart_ciram_ce_n && !ppu_rd_n)
            ciram_data <= ciram_raw;
    end

    mem #(
        .ADDR_WIDTH(11)
    ) u_ciram (
        .clk(ppu_clk),
        .addr({cart_ciram_a10, ppu_addr[9:0]}),
        .data_in(ppu_data),
        .data_out(ciram_raw),
        .rw(ppu_wr_n),
        .cs_n(cart_ciram_ce_n),
        .oe_n(ppu_rd_n)
    );

endmodule
