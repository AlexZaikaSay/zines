
module ff #(
    parameter RESET_VALUE = 0
) (
    input logic clk,
    input logic rst_n,
    input logic [7:0] d,
    input logic en,
    output logic [7:0] q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= RESET_VALUE;
        else if (en)
            q <= d;
    end

endmodule
