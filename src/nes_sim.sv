
`include "cpu/mos6502.sv"
`include "ppu/ppu2C02.sv"

module nes_sim (
    input logic cpu_clk,
    input logic ppu_clk,
    input logic rst_n
);

    logic           nmi_n;
    logic [15:0]    cpu_addr;
    logic [7:0]     cpu_data;

    mos6502 u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .irq_n(1'b1),
        .nmi_n(nmi_n),
        .addr(cpu_addr),
        .data_out(cpu_data)
    );


    ppu2C02 u_ppu (
        .clk(ppu_clk),
        .rst_n(rst_n),
        .nmi_n(nmi_n),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in)
    );



endmodule
