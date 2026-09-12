module ff_status (
    input logic clk,
    input logic rst,
    input logic c,
    input logic z,
    input logic i,
    input logic d,
    input logic v,
    input logic n,
    input logic w_c,
    input logic w_z,
    input logic w_i,
    input logic w_d,
    input logic w_v,
    input logic w_n,
    output logic [7:0] q
);

    parameter RESET_VALUE = 8'bxx1101xx;
    parameter C_FLAG = 0;
    parameter Z_FLAG = 1;
    parameter I_FLAG = 2;
    parameter D_FLAG = 3;
    parameter V_FLAG = 6;
    parameter N_FLAG = 7;


    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            q <= RESET_VALUE;
        else begin
            if (w_c)
                q[C_FLAG] <= c;
            if (w_z)
                q[Z_FLAG] <= z;
            if (w_i)
                q[I_FLAG] <= i;
            if (w_d)
                q[D_FLAG] <= d;
            if (w_v)
                q[V_FLAG] <= v;
            if (w_n)
                q[N_FLAG] <= n;
        end
    end

endmodule
