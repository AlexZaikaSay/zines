

module main_fsm (
    input logic         clk,
    input logic         rst,
    input logic [7:0]   imm,
    input logic [7:0]   inst,
    output logic        c,
    output logic        i,
    output logic        d,
    output logic        v,
    output logic        w_c,
    output logic        w_z,
    output logic        w_i,
    output logic        w_d,
    output logic        w_v,
    output logic        w_n,
    output logic        w_next_pc,
    output logic        w_inst,
    output logic        w_a,
    output logic        w_x,
    output logic        w_y,
    output logic        src_next_pc_h,
    output logic        src_next_pc_l,
    output logic        src_addr_h,
    output logic        src_addr_l,
    output logic        src_a,
    output logic        src_x,
    output logic        src_y,
    output logic        src_alu_a,
    output logic        src_alu_b,
    output logic [2:0]  alu_op
);
  typedef enum logic [3:0] {
        Fetch,      // Fetch
        StoreFlags, // CLC, SEC, CLI, SEI, CLV, CLD, SED
        StoreImm   // LDA, LDX, LDY immediate
    } state_t;

    state_t state, next_state;

    parameter OP_CLC        = 8'h18;
    parameter OP_SEC        = 8'h38;
    parameter OP_CLI        = 8'h58;
    parameter OP_SEI        = 8'h78;
    parameter OP_CLV        = 8'hB8;
    parameter OP_CLD        = 8'hD8;
    parameter OP_SED        = 8'hF8;
    parameter OP_LDA_imm    = 8'hA9;
    parameter OP_LDX_imm    = 8'hA2;
    parameter OP_LDY_imm    = 8'hA0;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= Fetch;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin 
        case (state)
            Fetch: begin
                casez (imm)
                    OP_CLC,
                    OP_SEC,
                    OP_CLI,
                    OP_SEI,
                    OP_CLV,
                    OP_CLD,
                    OP_SED: 
                        next_state = StoreFlags; 
                    OP_LDA_imm,
                    OP_LDX_imm,
                    OP_LDY_imm: 
                        next_state = StoreImm; 
                    default: 
                        next_state = Fetch;
                endcase
            end
            StoreFlags: begin
                next_state = Fetch;
            end
            StoreImm: begin
                next_state = Fetch;
            end
            default: begin
                next_state = Fetch;
            end
        endcase
    end

    always_comb begin 
        case (state)
            Fetch: begin
                // Fetch state logic
                c = 0;
                w_c = 0;
                i = 0;
                w_i = 0;
                v = 0;
                w_v = 0;
                d = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc = 1;      // write next PC
                w_inst = 1;         // write instruction
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 3'b000;
            end
            StoreFlags: begin
                // StoreFlags state logic
                casez (inst)
                    OP_CLC: begin
                        // CLC
                        c = 0;      // C flag is 0
                        w_c = 1;    // write C flag
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    OP_SEC: begin
                        // SEC
                        c = 1;      // C flag is 1
                        w_c = 1;    // write C flag
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    OP_CLI: begin
                        // CLI
                        c = 0;
                        w_c = 0;
                        i = 0;      // I flag is 0
                        w_i = 1;    // write I flag
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    OP_SEI: begin
                        // SEI
                        c = 0;
                        w_c = 0;
                        i = 1;      // I flag is 1
                        w_i = 1;    // write I flag
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    OP_CLV: begin
                        // CLV
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;      // V flag is 0
                        w_v = 1;    // write V flag
                        d = 0;
                        w_d = 0;
                    end
                    OP_CLD: begin
                        // CLD
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;      // D flag is 0
                        w_d = 1;    // write D flag
                    end
                    OP_SED: begin
                        // SED
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 1;      // D flag is 1
                        w_d = 1;    // write D flag
                    end
                    default: begin
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                endcase
                w_z = 0;
                w_n = 0;
                w_next_pc = 0;
                w_inst = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 3'b000;
            end
            StoreImm: begin
                case (inst)
                    OP_LDA_imm: begin
                        // Load Accumulator with Immediate
                        w_a = 1;        // write A register
                        src_a = 0;      // source A is Alu output
                        w_x = 0;
                        src_x = 0;
                        w_y = 0;
                        src_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is imm
                        alu_op = 3'b010; // ALU operation is pass B
                    end
                    OP_LDX_imm: begin
                        // Load X register with Immediate
                        w_a = 0;
                        src_a = 0;
                        w_x = 1;        // write X register
                        src_x = 0;      // source X is Alu output
                        w_y = 0;
                        src_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is imm
                        alu_op = 3'b010;// ALU operation is pass B
                    end
                    OP_LDY_imm: begin
                        // Load Y register with Immediate
                        w_a = 0;
                        src_a = 0;                        
                        w_x = 0;
                        src_x = 0;
                        w_y = 1;        // write Y register
                        src_y = 0;      // source Y is Alu output
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is imm
                        alu_op = 3'b010;// ALU operation is pass B
                    end
                    default: begin
                        w_a = 0;
                        src_a = 0;                        
                        w_x = 0;
                        src_x = 0;
                        w_y = 0; 
                        src_y = 0;
                        src_alu_a = 0;
                        src_alu_b = 0;
                        alu_op = 3'b000; 
                    end
                endcase
                c = 0;
                w_c = 0;
                i = 0;
                w_i = 0;
                v = 0;
                w_v = 0;
                d = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc = 1;      // write next PC
                w_inst = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
            end
            default: begin
                // Default state logic
                c = 0;
                w_c = 0;
                i = 0;
                w_i = 0;
                v = 0;
                w_v = 0;
                d = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc = 0;
                w_inst = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 3'b000;
            end
        endcase
    end

endmodule
