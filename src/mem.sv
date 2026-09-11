

module mem #(
    parameter MEM_FILE = ""
) (
    input logic clk,
    input logic [15:0] addr,
    output logic [7:0] rd,
    input logic [7:0] wd,
    input logic we
);
    logic [7:0] data [0:65535];
    
    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, data);
        end
    end

    always_ff @(posedge clk) begin
        if (we) begin
            data[addr] <= wd;
        end
    end

    assign rd = data[addr];

endmodule
