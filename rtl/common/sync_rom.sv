// ROM with a registered read, initialised from a hex file; maps to FPGA block RAM.
// data_out is updated on the clock edge after addr is presented while re = 1.
module sync_rom #(
    parameter integer ADDR_WIDTH = 15,
    parameter ROM_FILE = ""             // untyped: Quartus doesn't support `string`
) (
    input  logic                  clk,
    input  logic                  re,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [7:0]            data_out
);
    logic [7:0] data [0:(1<<ADDR_WIDTH)-1];

    initial begin
        if (ROM_FILE != "")
            $readmemh(ROM_FILE, data);
    end

    always_ff @(posedge clk) begin
        if (re)
            data_out <= data[addr];
    end

endmodule
