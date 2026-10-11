
`include "cpu/mem.sv"
`include "cpu/cpu2A03.sv"

module rp_devboard 
#(
    parameter MEM_FILE = ""
)
(
    input logic clk,
    input logic cpu_clk,
    input logic rst_n,
    input logic nmi_n = 1'b1,
    input logic irq_n = 1'b1
);

    logic [15:0] addr;
    logic [7:0] cpu_data;
    logic [7:0] mem_data;
    logic rw;

    cpu2A03 cpu (
        .clk,
        .cpu_clk,
        .rst_n,
        .addr,
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
        .clk(cpu_clk),
        .addr(addr),
        .data_out(mem_data),
        .data_in(cpu_data),
        .rw(rw)
    );

endmodule
