
`include "mem.sv"
`include "mos6502.sv"

module devboard 
#(
    parameter MEM_FILE = "",
    parameter PC_START = 16'h0000
)
(
    input logic clk,
    input logic rst
);

    logic [15:0] addr;
    logic [7:0] mem_rd;
    logic [7:0] mem_wd;
    logic we;

    mos6502 #(
        .PC_START(PC_START)
    )
    cpu (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .data_out(mem_wd),
        .data_in(mem_rd),
        .we(we)
    );

    mem #(
        .MEM_FILE(MEM_FILE)
    ) memory (
        .clk(clk),
        .addr(addr),
        .rd(mem_rd),
        .wd(mem_wd),
        .we(we)
    );

endmodule
