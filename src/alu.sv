
module alu (
    input  logic [2:0] alu_op,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] result,
    output logic  v,
    output logic  n,
    output logic  c,
    output logic  z
);

    logic [7:0] and_out;
    logic [7:0] or_out;
    logic [7:0] add_out;
    logic [7:0] b_in;
    logic [7:0] xor_out;

    parameter ALU_ADD  = 0;
    parameter ALU_SUB  = 1;
    parameter ALU_A    = 2;
    parameter ALU_B    = 3;
    parameter ALU_AND  = 4;
    parameter ALU_OR   = 5;
    parameter ALU_EOR  = 6;

    always @*
    begin

        if (alu_op[0]) 
            b_in = ~b + 1;
        else 
            b_in = b;

        {c, add_out} = a + b_in;
        and_out = a & b;
        or_out  = a | b;
        xor_out = a ^ b;

        casez (alu_op)
            ALU_A:    result = a;
            ALU_B:    result = b;
            ALU_ADD:  result = add_out;
            ALU_SUB:  result = add_out;
            ALU_AND:  result = and_out;
            ALU_OR:   result = or_out;
            ALU_EOR:  result = xor_out;
            default:  result = 8'bz;
        endcase
    end

    assign v = (a[7] ^ b_in[7]) & (a[7] ^ result[7]);
    assign z = (result == 8'b0);
    assign n = result[7];

endmodule
