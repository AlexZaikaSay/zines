
`include "cpu/mem.sv"
`include "cpu/mos6502.sv"

module devboard 
#(
    parameter MEM_FILE = "",
    parameter PC_START = 16'h0000
)
(
    input logic clk,
    input logic rst_n,
    input logic nmi_n = 1'b1,
    input logic irq_n = 1'b1
);

    logic [15:0] addr;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic we;

    mos6502 #(
        .PC_START(PC_START)
    )
    cpu (
        .clk,
        .rst_n,
        .addr(addr),
        .data_out(data_out),
        .data_in(data_in),
        .we(we),
        .nmi_n,
        .irq_n
    );

    mem #(
        .MEM_FILE(MEM_FILE)
    ) memory (
        .clk,
        .addr(addr),
        .rd(data_in),
        .wd(data_out),
        .we(we)
    );

endmodule
