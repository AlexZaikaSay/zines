
`include "cpu/mem.sv"
`include "cpu/mos6502.sv"

module devboard 
#(
    parameter MEM_FILE = ""
)
(
    input logic clk,
    input logic rst_n,
    input logic nmi_n = 1'b1,
    input logic irq_n = 1'b1
);

    logic [15:0] addr;
    logic [7:0] cpu_data;
    logic [7:0] mem_data;
    logic rw;

    mos6502 cpu (
        .clk,
        .rst_n,
        .addr(addr),
        .data_out(cpu_data),
        .data_in(mem_data),
        .rw(rw),
        .nmi_n,
        .irq_n
    );

    mem #(
        .ADDR_WIDTH(16),
        .MEM_FILE(MEM_FILE)
    ) memory (
        .clk,
        .addr(addr),
        .data_out(mem_data),
        .data_in(cpu_data),
        .rw(rw)
    );

endmodule
