

module mem #(
    parameter MEM_FILE = ""
) (
    input logic clk,
    input logic [15:0] addr,
    output logic [7:0] data_out,
    input logic [7:0] data_in,
    input logic rw
);
    logic [7:0] data [0:65535];
    
    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, data);
        end
    end

    always_ff @(posedge clk) begin
        if (!rw) begin
            data[addr] <= data_in;
        end
    end

    assign data_out = data[addr];

endmodule
