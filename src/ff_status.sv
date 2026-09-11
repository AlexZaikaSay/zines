module ff_status (
    input logic clk,
    input logic rst,
    input logic c,
    input logic i,
    input logic v,
    input logic d,
    input logic w_c,
    input logic w_i,
    input logic w_v,
    input logic w_d,
    output logic [7:0] q
);

    parameter RESET_VALUE = 8'bxx1101xx;
    parameter C_FLAG = 0;
    parameter I_FLAG = 2;
    parameter D_FLAG = 3;
    parameter V_FLAG = 6;


    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            q <= RESET_VALUE;
        end else if (w_c) begin
            q[C_FLAG] <= c;
        end else if (w_i) begin
            q[I_FLAG] <= i;
        end else if (w_v) begin
            q[V_FLAG] <= v;
        end else if (w_d) begin
            q[D_FLAG] <= d;
        end
    end

endmodule
