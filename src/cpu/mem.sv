

module mem #(
    parameter MEM_FILE = "",
    parameter ADDR_WIDTH = 11
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [7:0] data_in,
    input logic rw,
    input logic cs_n = 1'b0,
    input logic oe_n = 1'b0,
    output logic [7:0] data_out
);
    logic [7:0] data [0:(1<<ADDR_WIDTH)-1];
    
    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, data);
        end
    end

    always_ff @(posedge clk) begin
        if (!cs_n && !rw) begin
            data[addr] <= data_in;
        end
    end

    assign data_out = (!cs_n && !oe_n) ? data[addr] : 8'hzz;

endmodule
