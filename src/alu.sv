
module alu (
    input  logic [3:0] alu_op,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] result,
    output logic  i,
    output logic  d,
    output logic  v,
    output logic  n,
    output logic  c,
    output logic  z
);

    logic [7:0] and_out;
    logic [7:0] or_out;
    logic [7:0] b_in;
    logic [7:0] xor_out;

    parameter ALU_ADD   = 0;
    parameter ALU_SUB   = 1;
    parameter ALU_A     = 2;
    parameter ALU_B     = 3;
    parameter ALU_AND   = 4;
    parameter ALU_OR    = 5;
    parameter ALU_EOR   = 6;
    parameter ALU_BIT   = 7;
    parameter ALU_SET_C = 8;
    parameter ALU_SET_D = 9;
    parameter ALU_SET_V = 10;
    parameter ALU_SET_I = 11;


    always @*
    begin

        if (alu_op == ALU_SUB) 
            b_in = ~b + 1;
        else 
            b_in = b;

        
        and_out = a & b;
        or_out  = a | b;
        xor_out = a ^ b;

        case (alu_op)
            ALU_A: begin
                result = a;
                i = 0;
                d = 0;
                v = 0;
                n = 0;
                c = 0;
            end
            ALU_B: begin
                result = b;
                i = 0;
                d = 0;
                v = 0;
                n = result[7];
                c = 0;
            end
            ALU_SUB,
            ALU_ADD: begin  
                {c, result} = a + b_in;
                i = 0;
                d = 0;
                v = (a[7] ^ b_in[7]) & (a[7] ^ result[7]);
                n = result[7];
            end
            ALU_AND: begin
                result = and_out;
                i = 0;
                d = 0;
                v = 0;
                n = result[7];
                c = 0;
            end
            ALU_OR: begin
                result = or_out;
                i = 0;
                d = 0;
                v = 0;
                n = result[7];
                c = 0;
            end
            ALU_EOR: begin
                result = xor_out;
                i = 0;
                d = 0;
                v = 0;
                n = result[7];
                c = 0;
            end
            ALU_BIT: begin
                result = and_out;
                i = 0;
                d = 0;
                v = b[6];
                n = b[7];
                c = 0;
            end
            ALU_SET_C: begin
                result = b;
                i = 0;
                d = 0;
                v = 0;
                n = 0;
                c = b[0];
            end
            ALU_SET_V: begin
                result = b;
                i = 0;
                d = 0;
                v = b[0];
                n = 0;
                c = 0;
            end
            ALU_SET_I: begin
                result = b;
                i = b[0];
                d = 0;
                v = 0;
                n = 0;
                c = 0;
            end
            ALU_SET_D: begin
                result = b;
                i = 0;
                d = b[0];
                v = 0;
                n = 0;
                c = 0;
            end
            default: begin
                result = 8'bz;
                i = z;
                d = z;
                v = z;
                n = z;
                c = z;
            end
        endcase
    end

    assign z = (result == 8'b0);

endmodule
