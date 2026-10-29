// Single-port RAM with a registered read, the shape FPGA block RAM (M9K) implements.
// data_out is updated on the clock edge after addr is presented while re = 1, and holds
// otherwise. Read-during-write returns the old contents.
module sync_ram #(
    parameter integer ADDR_WIDTH = 11,
    parameter integer DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic                  re,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);
    logic [DATA_WIDTH-1:0] data [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        if (we)
            data[addr] <= data_in;
        if (re)
            data_out <= data[addr];
    end

endmodule
