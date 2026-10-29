// Single-port ROM with a registered read, the shape FPGA block ROM (M9K) implements.
// data_out is updated on the clock edge after addr is presented while re = 1, and holds
// otherwise. Read-during-write returns the old contents.
module rom #(
    parameter ROM_FILE = "",
    parameter integer ADDR_WIDTH = 15
) (
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic                  re,
    output logic [7:0] data_out
);
    logic [7:0] data [0:(1<<ADDR_WIDTH)-1];

    initial begin
        if (ROM_FILE != "") begin
            $display("Loading ROM from file: %s", ROM_FILE);
            $readmemh(ROM_FILE, data);
        end
    end

    assign data_out = re ? data[addr] : 8'hff;

endmodule
