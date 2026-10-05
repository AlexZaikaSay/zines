
module alu (
    input  logic [3:0] alu_op,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic  c_in,
    output logic [7:0] result,
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
    parameter ALU_CORR  = 7;
    parameter ALU_ASL   = 8;
    parameter ALU_LSR   = 9;
    parameter ALU_ROR   = 10;
    parameter ALU_ROL   = 11;


    always @(*)
    begin

        and_out = a_in & b_in;
        or_out  = a_in | b_in;
        xor_out = a_in ^ b_in;

        case (alu_op)
            ALU_A: begin
                result = a_in;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_B: begin
                result = b_in;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_SUB: begin  
                {c, result} = {1'b0, a_in} + {1'b0, ~b_in} + {8'b0, c_in};
                v = (a_in[7] ^ b_in[7]) & (a_in[7] ^ result[7]);
                n = result[7];
                z = (result == 8'b0);
            end
            ALU_ADD: begin  
                {c, result} = {1'b0, a_in} + {1'b0, b_in} + {8'b0, c_in};
                v = (~(a_in[7] ^ b_in[7])) & (a_in[7] ^ result[7]);
                n = result[7];
                z = (result == 8'b0);
            end
            ALU_CORR: begin
                {c, result} = {1'b0, a_in} + {1'b0, b_in};
                v = (a_in[7] ^ b_in[7]) & (a_in[7] ^ result[7]);
                n = 0;
                z = (result == 8'b0);
            end
            ALU_AND: begin
                result = and_out;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_OR: begin
                result = or_out;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_EOR: begin
                result = xor_out;
                v = 0;
                n = result[7];
                c = 0;
                z = (result == 8'b0);
            end
            ALU_ASL: begin
                result = {a_in[6:0], 1'b0};
                v = 0;
                n = result[7];
                c = a_in[7];
                z = (result == 8'b0);
            end
            ALU_LSR: begin
                result = {1'b0, a_in[7:1]};
                v = 0;
                n = 0;
                c = a_in[0];
                z = (result == 8'b0);
            end
            ALU_ROR: begin
                result = {c_in, a_in[7:1]};
                v = 0;
                n = c_in;
                c = a_in[0];
                z = (result == 8'b0);
            end
            ALU_ROL: begin
                result = {a_in[6:0], c_in};
                v = 0;
                n = result[7];
                c = a_in[7]; 
                z = (result == 8'b0);
            end
            default: begin
                result = 8'bz;
                v = 0;
                n = 0;
                c = 0;
                z = 0;
            end
        endcase
    end

endmodule
