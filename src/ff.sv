
module ff #(
    parameter RESET_VALUE = 0
) (
    input logic clk,
    input logic rst,
    input logic [7:0] d,
    input logic en,
    output logic [7:0] q
);

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            q <= RESET_VALUE;
        else if (en)
            q <= d;
    end

endmodule