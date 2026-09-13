

module main_fsm (
    input logic         clk,
    input logic         rst,
    input logic [7:0]   imm,
    input logic [7:0]   inst,
    input logic [7:0]   flags,
    input logic         alu_v,
    input logic         alu_c,
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
    output logic        w_next_pc_h,
    output logic        w_next_pc_l,
    output logic        w_inst,
    output logic        w_low_byte,
    output logic        w_a,
    output logic        w_x,
    output logic        w_y,
    output logic [1:0]  src_next_pc_h,
    output logic [1:0]  src_next_pc_l,
    output logic        src_addr_h,
    output logic        src_addr_l,
    output logic        src_a,
    output logic        src_x,
    output logic        src_y,
    output logic [1:0]  src_alu_a,
    output logic [1:0]  src_alu_b,
    output logic [2:0]  alu_op
);
  typedef enum logic [3:0] {
        Fetch,          // Fetch
        StoreFlags,     // StoreFlags for CLC, SEC, CLI, SEI, CLV, CLD, SED
        StoreImm,       // StoreImm to register for LDA, LDX, LDY immediate
        JmpLowByte,     // Handle low byte of JMP absolute
        JmpHighByte,    // Handle high byte of JMP absolute
        Branch,         // Handle branch instructions (BNE, BEQ)
        BranchTaken,    // Handle branch taken
        BranchCrossInc, // Handle branch taken with +1 page
        BranchCrossDec, // Handle branch taken with -1 page
        Nothing         // do nothing for NOP
    } state_t;

    state_t state, next_state;
    logic n_flag;
    logic z_flag;
    logic c_flag;

    assign z_flag = flags[1];
    assign n_flag = flags[7];
    assign c_flag = flags[0];


    parameter OP_NOP        = 8'hEA;
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
    parameter OP_JMP_abs    = 8'h4C;
    parameter OP_BNE        = 8'hD0;
    parameter OP_BEQ        = 8'hF0;
    parameter OP_BPL        = 8'h10;
    parameter OP_BMI        = 8'h30;
    parameter OP_BCC        = 8'h90;
    parameter OP_BCS        = 8'hB0;

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
                    OP_NOP: 
                        next_state = Nothing;
                    OP_JMP_abs:
                        next_state = JmpLowByte;
                    OP_BNE,
                    OP_BEQ,
                    OP_BPL,
                    OP_BMI,
                    OP_BCC,
                    OP_BCS:
                        next_state = Branch;
                    default: 
                        next_state = Fetch;
                endcase
            end
            JmpLowByte: begin
                next_state = JmpHighByte;
            end
            Branch: begin
                casez (inst)
                    OP_BNE: begin
                        // BNE
                        if (~z_flag)
                            // BNE is taken if Z flag is 0
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;  
                    end
                    OP_BEQ: begin
                        // BEQ
                        if (z_flag)
                            // BEQ is taken if Z flag is 1
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;
                    end
                    OP_BPL: begin
                        // BPL
                        if (~n_flag)
                            // BPL is taken if N flag is 0
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;
                    end
                    OP_BMI: begin
                        // BMI
                        if (n_flag)
                            // BMI is taken if N flag is 1
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;
                    end
                    OP_BCC: begin
                        // BCC
                        if (~c_flag)
                            // BCC is taken if C flag is 0
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;
                    end
                    OP_BCS: begin
                        // BCS
                        if (c_flag)
                            // BCS is taken if C flag is 1
                            next_state = BranchTaken; 
                        else
                            next_state = Fetch;
                    end
                    default: begin
                        // Default: branch not taken
                        next_state = Fetch;
                    end
                endcase
            end
            BranchTaken: begin
                if (alu_v)
                    // Cross page if pc_l sum overflows
                    if (alu_c)
                        // Increment page if branch up
                        next_state = BranchCrossInc;
                    else
                        // Decrement page if branch down
                        next_state = BranchCrossDec;
                else
                    // Branch not crossing page
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 1;         // write instruction
                w_low_byte = 0;
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
                alu_op = 0;
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
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_low_byte = 0;
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
                alu_op = 0;
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
                        alu_op = 2;     // ALU operation is pass B
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
                        alu_op = 2;     // ALU operation is pass B
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
                        alu_op = 2;     // ALU operation is pass B
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
                        alu_op = 0; 
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_low_byte = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
            end
            JmpLowByte: begin
                // Logic for handling low byte of JMP absolute
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_low_byte = 1;     // write low byte of JMP address
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
                alu_op = 0;
            end
            JmpHighByte: begin
                // Logic for handling high byte of JMP absolute
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 1;  // source next PC low byte is low_byte
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            Branch: begin
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_low_byte = 1;     // write low byte - branch offset
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
                alu_op = 0;
            end
            BranchTaken: begin
                // Logic for handling branch taken
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
                w_next_pc_h = 0;
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 2;  // source next PC low byte is ALU result
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 1;      // source ALU A is PC low byte
                src_alu_b = 1;      // source ALU B is low byte
                alu_op = 0;         // ALU operation: ADD
            end
            BranchCrossInc: begin
                // Logic for handling branch taken with +1 page
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_inst = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 2;  // source next PC low byte is ALU result
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 2;      // source ALU A is PC hi byte
                src_alu_b = 2;      // source ALU B is 1
                alu_op = 0;         // ALU operation: ADD
            end
            BranchCrossDec: begin
                // Logic for handling branch taken with -1 page
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
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_inst = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                src_next_pc_h = 2;  // source next PC low byte is ALU result
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_a = 0;
                src_x = 0;
                src_y = 0;
                src_alu_a = 2;      // source ALU A is PC hi byte
                src_alu_b = 2;      // source ALU B is 1
                alu_op = 1;         // ALU operation: SUB
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
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_low_byte = 0;
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
                alu_op = 0;
            end
        endcase
    end

endmodule
