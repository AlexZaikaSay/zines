
module alu (
    input  logic [4:0] alu_op,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic  c_in,
    output logic [7:0] result,
    output logic  i,
    output logic  d,
    output logic  b,
    output logic  v,
    output logic  n,
    output logic  c,
    output logic  z
);

    logic [7:0] and_out;
    logic [7:0] or_out;
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
    parameter ALU_CORR  = 12;
    parameter ALU_FLAGS = 13;
    parameter ALU_SET_B = 14;
    parameter ALU_ASL   = 15;
    parameter ALU_LSR   = 16;
    parameter ALU_ROR   = 17;
    parameter ALU_ROL   = 18;


    always @(*)
    begin

        and_out = a_in & b_in;
        or_out  = a_in | b_in;
        xor_out = a_in ^ b_in;

        case (alu_op)
            ALU_A: begin
                result = a_in;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_B: begin
                result = b_in;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_SUB: begin  
                {c, result} = {1'b0, a_in} + {1'b0, ~b_in} + {8'b0, c_in};
                i = 0;
                d = 0;
                b = 0;
                v = (a_in[7] ^ b_in[7]) & (a_in[7] ^ result[7]);
                n = result[7];
                z = (result == 8'b0);
            end
            ALU_ADD: begin  
                {c, result} = {1'b0, a_in} + {1'b0, b_in} + {8'b0, c_in};
                i = 0;
                d = 0;
                b = 0;
                v = (~(a_in[7] ^ b_in[7])) & (a_in[7] ^ result[7]);
                n = result[7];
                z = (result == 8'b0);
            end
            ALU_CORR: begin
                {c, result} = {1'b0, a_in} + {1'b0, b_in};
                i = 0;
                d = 0;
                b = 0;
                v = (a_in[7] ^ b_in[7]) & (a_in[7] ^ result[7]);
                n = 0;
                z = (result == 8'b0);
            end
            ALU_AND: begin
                result = and_out;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_OR: begin
                result = or_out;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_EOR: begin
                result = xor_out;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_BIT: begin
                result = and_out;
                i = 0;
                d = 0;
                b = 0;
                v = b_in[6];
                n = b_in[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_SET_C: begin
                result = b_in;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = 0;
                c = b_in[0];
                z = 0;
            end
            ALU_SET_V: begin
                result = b_in;
                i = 0;
                d = 0;
                b = 0;
                v = b_in[0];
                n = 0;
                c = 0;
                z = 0;
            end
            ALU_SET_I: begin
                result = b_in;
                i = b_in[0];
                d = 0;
                b = 0;
                v = 0;
                n = 0;
                c = 0;
                z = 0;
            end
            ALU_SET_B: begin
                result = b_in;
                i = 0;
                d = 0;
                b = b_in[0];
                v = 0;
                n = 0;
                c = 0;
                z = 0;
            end
            ALU_SET_D: begin
                result = b_in;
                i = 0;
                d = b_in[0];
                b = 0;
                v = 0;
                n = 0;
                c = 0;
                z = 0;
            end
            ALU_FLAGS: begin
                result = b_in;
                i = b_in[2];
                d = b_in[3];
                b = 0;
                v = b_in[6];
                n = b_in[7];
                c = b_in[0];
                z = b_in[1];
            end
            ALU_ASL: begin
                result = {a_in[6:0], 1'b0};
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = a_in[7];
                z = (result == 8'b0);
            end
            ALU_LSR: begin
                result = {1'b0, a_in[7:1]};
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = 0;
                c = a_in[0];
                z = (result == 8'b0);
            end
            ALU_ROR: begin
                result = {c_in, a_in[7:1]};
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = c_in;
                c = a_in[0];
                z = (result == 8'b0);
            end
            ALU_ROL: begin
                result = {a_in[6:0], c_in};
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = result[7];
                c = a_in[7]; 
                z = (result == 8'b0);
            end
            default: begin
                result = 8'bz;
                i = 0;
                d = 0;
                b = 0;
                v = 0;
                n = 0;
                c = 0;
                z = 0;
            end
        endcase
    end

endmodule
