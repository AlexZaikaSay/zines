`include "cpu/cpu2A03.sv"
`include "cpu/mem.sv"
`include "cpu/decoder2_4.sv"
`include "ppu/ppu2C02.sv"

module nes_sim (
    input  logic       cpu_clk,
    input  logic       ppu_clk,
    input  logic       rst_n,
    output logic [8:0] scanline,
    output logic [8:0] cycle,
    output logic [4:0] video,
    output logic [7:0] pixel_palette,

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
    input  logic        cart_ciram_ce_n
);

    logic        nmi_n;
    logic [15:0] cpu_addr;
    logic [7:0]  cpu_data_out;
    logic [7:0]  cpu_data_in;
    logic        cpu_rw;
    logic        cpu_m2;
    logic        cpu_undef;
    logic        cpu_strobe;
    logic [7:0]  cpu_ram_data;
    logic [3:0]  cpu_page_select;
    logic [3:0]  cpu_upper_select;
    logic [7:0]  ppu_cpu_data;

    wire cpu_ram_selected = !cpu_addr[15] && cpu_page_select[0];
    wire ppu_register_selected = !cpu_addr[15] && cpu_page_select[1];
    wire cartridge_selected = cpu_upper_select[2] || cpu_upper_select[3];
    wire ppu_register_access = cpu_strobe && ppu_register_selected;

    always_ff @(posedge ppu_clk or negedge rst_n) begin
        if (!rst_n)
            cpu_strobe <= 1'b0;
        else
            cpu_strobe <= cpu_clk;
    end

    decoder2_4 cpu_address_decoder (
        .a(cpu_addr[14:13]),
        .en_n(cpu_addr[15]),
        .y(cpu_page_select)
    );

    decoder2_4 cartridge_address_decoder (
        .a(cpu_addr[15:14]),
        .en_n(1'b0),
        .y(cpu_upper_select)
    );

    cpu2A03 u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n),
        .irq_n(1'b1),
        .data_in(cpu_data_in),
        .data_out(cpu_data_out),
        .addr(cpu_addr),
        .rw(cpu_rw),
        .m2(cpu_m2),
        .undef(cpu_undef)
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
        if (cartridge_selected)
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
    wire  [7:0]  ciram_data;      // shared PPU data bus
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
        .video(video),
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
    assign ppu_data = !ppu_wr_n ? ppu_data_out : 8'hzz;
    assign ppu_data = ciram_data;
    assign ppu_data = (cart_ciram_ce_n && ppu_wr_n) ? cart_ppu_data_in : 8'hzz;

    mem #(
        .ADDR_WIDTH(11)
    ) u_ciram (
        .clk(ppu_clk),
        .addr({cart_ciram_a10, ppu_addr[9:0]}),
        .data_in(ppu_data),
        .data_out(ciram_data),
        .rw(ppu_wr_n),
        .cs_n(cart_ciram_ce_n),
        .oe_n(ppu_rd_n)
    );

endmodule
