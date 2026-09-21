

module main_fsm (
    input logic         clk,
    input logic         rst,
    input logic [7:0]   imm,
    input logic [7:0]   inst,
    input logic [7:0]   flags,
    input logic         c,
    input logic         v,
    output logic        w_c,
    output logic        w_z,
    output logic        w_i,
    output logic        w_d,
    output logic        w_v,
    output logic        w_n,
    output logic        w_next_pc_h,
    output logic        w_next_pc_l,
    output logic        w_inst,
    output logic        w_high_byte,
    output logic        w_low_byte,
    output logic        w_a,
    output logic        w_x,
    output logic        w_y,
    output logic        w_s,
    output logic        w_mem,
    output logic [1:0]  src_c_in, // TODO: check later if it really needs
    output logic [1:0]  src_next_pc_h,
    output logic [1:0]  src_next_pc_l,
    output logic        src_addr_h,
    output logic        src_addr_l,
    output logic [2:0]  src_alu_a,
    output logic [1:0]  src_alu_b,
    output logic [3:0]  alu_op,
    output logic        undef
);
  typedef enum logic [4:0] {
        Fetch,          // Fetch
        LoadFlags,      // LoadFlags for CLC, SEC, CLI, SEI, CLV, CLD, SED
        LoadImm,        // Load immediate value into A, X, or Y
        CompareImm,     // Compare immediate value with A
        AluImm,         // Arithmetic/Logic (ADC, SBC, AND, ORA, EOR) with immediate values
        FetchLoByte,    // Fetch low byte of absolute address
        FetchHiByte,    // Fetch high byte of absolute address
        Store,          // Store value of A to memory
        Load,           // Load from memory to A, X, or Y
        Bit,            // Handle BIT instruction
        JmpAbs,         // Handle high byte of JMP absolute
        Branch,         // Handle branch instructions (BNE, BEQ)
        BranchTaken,    // Handle branch taken
        BranchCrossInc, // Handle branch taken with +1 page
        BranchCrossDec, // Handle branch taken with -1 page
        Transfer,       // Handle transfer instructions (TSX, TAX, TXA, TAY, TYA)
        TransferStack,  // Handle transfer instructions TXS
        IncDec,         // Handle inc and dec instructions (INX, INY, DEX, DEY)
        Nothing         // do nothing for NOP
    } state_t;

    state_t state, next_state;
    logic c_flag;
    logic z_flag;
    logic v_flag;
    logic n_flag;

    assign c_flag = flags[0];
    assign z_flag = flags[1];
    assign v_flag = flags[6];
    assign n_flag = flags[7];

    parameter OP_ORA_imm    = 8'h09;
    parameter OP_BPL        = 8'h10;
    parameter OP_CLC        = 8'h18;
    parameter OP_AND_imm    = 8'h29;
    parameter OP_BIT_abs    = 8'h2C;
    parameter OP_BMI        = 8'h30;
    parameter OP_SEC        = 8'h38;
    parameter OP_EOR_imm    = 8'h49;
    parameter OP_JMP_abs    = 8'h4C;
    parameter OP_BVC        = 8'h50;
    parameter OP_CLI        = 8'h58;
    parameter OP_ADC_imm    = 8'h69;
    parameter OP_BVS        = 8'h70;
    parameter OP_SEI        = 8'h78;
    parameter OP_DEY        = 8'h88;
    parameter OP_TXA        = 8'h8A;
    parameter OP_STY_abs    = 8'h8C;
    parameter OP_STA_abs    = 8'h8D;
    parameter OP_STX_abs    = 8'h8E;
    parameter OP_BCC        = 8'h90;
    parameter OP_TYA        = 8'h98;
    parameter OP_TXS        = 8'h9A;
    parameter OP_LDY_imm    = 8'hA0;
    parameter OP_LDX_imm    = 8'hA2;
    parameter OP_TAY        = 8'hA8;
    parameter OP_LDA_imm    = 8'hA9;
    parameter OP_TAX        = 8'hAA;
    parameter OP_LDY_abs    = 8'hAC;
    parameter OP_LDX_abs    = 8'hAE;
    parameter OP_LDA_abs    = 8'hAD;
    parameter OP_BCS        = 8'hB0;
    parameter OP_CLV        = 8'hB8;
    parameter OP_TSX        = 8'hBA;
    parameter OP_CPY_imm    = 8'hC0;
    parameter OP_INY        = 8'hC8;
    parameter OP_CMP_imm    = 8'hC9;
    parameter OP_DEX        = 8'hCA;
    parameter OP_BNE        = 8'hD0;
    parameter OP_CLD        = 8'hD8;
    parameter OP_CPX_imm    = 8'hE0;
    parameter OP_INX        = 8'hE8;
    parameter OP_SBC_imm    = 8'hE9;
    parameter OP_NOP        = 8'hEA;
    parameter OP_BEQ        = 8'hF0;
    parameter OP_SED        = 8'hF8;

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
                case (imm)
                    OP_CLC,
                    OP_SEC,
                    OP_CLI,
                    OP_SEI,
                    OP_CLV,
                    OP_CLD,
                    OP_SED: begin
                        undef = 0;
                        next_state = LoadFlags;
                    end
                    OP_LDA_imm,
                    OP_LDX_imm,
                    OP_LDY_imm: begin
                        undef = 0;
                        next_state = LoadImm;
                    end
                    OP_CMP_imm,
                    OP_CPX_imm,
                    OP_CPY_imm: begin
                        undef = 0;
                        next_state = CompareImm;
                    end
                    OP_AND_imm,
                    OP_ORA_imm,
                    OP_EOR_imm,
                    OP_ADC_imm,
                    OP_SBC_imm: begin
                        undef = 0;
                        next_state = AluImm;
                    end
                    OP_NOP: begin
                        undef = 0;
                        next_state = Nothing;
                    end
                    OP_JMP_abs: begin
                        undef = 0;
                        next_state = FetchLoByte;
                    end
                    OP_BNE,
                    OP_BEQ,
                    OP_BPL,
                    OP_BMI,
                    OP_BCC,
                    OP_BCS,
                    OP_BVC,
                    OP_BVS: begin
                        undef = 0;
                        next_state = Branch;
                    end
                    OP_TXS: begin
                        undef = 0;
                        next_state = TransferStack;
                    end
                    OP_TSX,
                    OP_TAX,
                    OP_TXA,
                    OP_TAY,
                    OP_TYA: begin
                        undef = 0;
                        next_state = Transfer;
                    end
                    OP_BIT_abs,
                    OP_LDA_abs,
                    OP_LDX_abs,
                    OP_LDY_abs,
                    OP_STA_abs,
                    OP_STX_abs,
                    OP_STY_abs: begin
                        undef = 0;
                        next_state = FetchLoByte;
                    end
                    OP_DEX,
                    OP_INX,
                    OP_DEY,
                    OP_INY: begin
                        undef = 0;
                        next_state = IncDec;
                    end
                    default: begin
                        undef = 1;
                        next_state = Fetch;
                    end
                endcase
            end
            FetchLoByte: begin
                case (inst)
                    OP_JMP_abs:
                        next_state = JmpAbs;
                    OP_BIT_abs,
                    OP_LDA_abs,
                    OP_LDX_abs,
                    OP_LDY_abs,
                    OP_STA_abs,
                    OP_STX_abs,
                    OP_STY_abs: 
                        next_state = FetchHiByte;
                    default:
                        next_state = Fetch;
                endcase
            end
            FetchHiByte: begin
                case (inst)
                    OP_LDA_abs,
                    OP_LDX_abs,
                    OP_LDY_abs: 
                        next_state = Load;
                    
                    OP_STA_abs,
                    OP_STX_abs,
                    OP_STY_abs:
                        next_state = Store;
                    OP_BIT_abs:
                        next_state = Bit;
                    default:
                        next_state = Fetch;
                endcase
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
                    OP_BVC: begin
                        // BVC
                        if (~v_flag)
                            // BVC is taken if V flag is 0
                            next_state = BranchTaken;
                        else
                            next_state = Fetch;
                    end
                    OP_BVS: begin
                        // BVS
                        if (v_flag)
                            // BVS is taken if V flag is 1
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
                if (v)
                    // Cross page if pc_l sum overflows
                    if (c)
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
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 1;         // write instruction
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            IncDec: begin
                // IncDec state logic
                casez (inst)
                    OP_DEX: begin
                        // DEX
                        src_c_in = 2;   // carry 1 for decrement
                        src_alu_a = 1;  // source ALU A is X register
                        alu_op = 1;     // ALU operation is SUB (for decrement)
                        w_x = 1;        // write X register
                        w_y = 0;
                    end
                    OP_INX: begin
                        // INX
                        src_c_in = 1;  // carry 0 for increment
                        src_alu_a = 1; // source ALU A is X register
                        alu_op = 0;    // ALU operation is ADD (for increment)
                        w_x = 1;       // write X register
                        w_y = 0;
                        
                    end
                    OP_DEY: begin
                        // DEY
                        src_c_in = 2;   // carry 1 for decrement
                        src_alu_a = 2; // source ALU A is Y register
                        alu_op = 1;    // ALU operation is SUB (for decrement)
                        w_x = 0;
                        w_y = 1;       // write Y register
                    end
                    OP_INY: begin
                        // INY
                        src_c_in = 1;  // carry 0 for increment
                        src_alu_a = 2; // source ALU A is Y register
                        alu_op = 0;    // ALU operation is ADD (for increment)
                        w_x = 0;
                        w_y = 1;       // write Y register
                    end
                    default: begin
                        src_c_in = 0;
                        src_alu_a = 0;
                        alu_op = 0;
                        w_x = 0;
                        w_y = 0;
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 1;
                w_n = 1;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 1;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_s = 0;
                w_mem = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;  
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_b = 3;      // source ALU B is 1
            end
            LoadFlags: begin
                // LoadFlags state logic
                casez (inst)
                    OP_CLC: begin
                        // CLC
                        src_alu_b = 2;  // source ALU B is 0
                        alu_op = 8;     // ALU operation is SET_C
                        w_c = 1;        // write C flag
                        w_i = 0;
                        w_v = 0;
                        w_d = 0;
                    end
                    OP_SEC: begin
                        // SEC
                        src_alu_b = 3;  // source ALU B is 1
                        alu_op = 8;     // ALU operation is SET_C
                        w_c = 1;        // write C flag
                        w_i = 0;
                        w_v = 0;
                        w_d = 0;
                    end
                    OP_CLI: begin
                        // CLI
                        src_alu_b = 2;  // source ALU B is 0
                        alu_op = 11;    // ALU operation is SET_I
                        w_c = 0;
                        w_i = 1;        // write I flag
                        w_v = 0;
                        w_d = 0;
                    end
                    OP_SEI: begin
                        // SEI
                        src_alu_b = 3;  // source ALU B is 1
                        alu_op = 11;    // ALU operation is SET_I
                        w_c = 0;
                        w_i = 1;        // write I flag
                        w_v = 0;
                        w_d = 0;
                    end
                    OP_CLV: begin
                        // CLV
                        src_alu_b = 2;  // source ALU B is 0
                        alu_op = 10;    // ALU operation is SET_V
                        w_c = 0;
                        w_i = 0;
                        w_v = 1;        // write V flag
                        w_d = 0;
                    end
                    OP_CLD: begin
                        // CLD
                        src_alu_b = 2;  // source ALU B is 0
                        alu_op = 9;     // ALU operation is SET_D
                        w_c = 0;
                        w_i = 0;
                        w_v = 0;
                        w_d = 1;        // write D flag
                    end
                    OP_SED: begin
                        // SED
                        src_alu_b = 3;  // source ALU B is 1
                        alu_op = 9;     // ALU operation is SET_D
                        w_c = 0;
                        w_i = 0;
                        w_v = 0;
                        w_d = 1;        // write D flag
                    end
                    default: begin
                        src_alu_b = 0;
                        alu_op = 0;
                        w_c = 0;
                        w_i = 0;
                        w_v = 0;
                        w_d = 0;
                    end
                endcase
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 0;
            end
            LoadImm: begin
                case (inst)
                    OP_LDA_imm: begin
                        // Load Accumulator with Immediate
                        w_a = 1;        // write A register
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDX_imm: begin
                        // Load X register with Immediate
                        w_a = 0;
                        w_x = 1;        // write X register
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDY_imm: begin
                        // Load Y register with Immediate
                        w_a = 0;
                        w_x = 0;
                        w_y = 1;        // write Y register
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    default: begin
                        w_a = 0;                  
                        w_x = 0;
                        w_y = 0; 
                        src_alu_a = 0;
                        src_alu_b = 0;
                        alu_op = 0; 
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
            end
            CompareImm: begin
                // Logic for handling compare immediate instruction
                case (inst)
                    OP_CMP_imm: 
                        src_alu_a = 0;      // source ALU A is A
                    OP_CPX_imm:
                        src_alu_a = 1;      // source ALU A is X
                    OP_CPY_imm:
                        src_alu_a = 2;      // source ALU A is Y
                    default:
                        src_alu_a = 0;
                endcase
                w_c = 1;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 1;
                w_n = 1;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_b = 0;      // source ALU B is data_in
                alu_op = 1;         // ALU operation is SUB
            end
            AluImm: begin
                // Logic for handling arithmetic immediate instruction
                case (inst)
                    OP_ADC_imm: begin
                        w_v = 1;    // write V flag
                        alu_op = 0; // ALU operation is ADD
                    end
                    OP_SBC_imm: begin
                        w_v = 1;    // write V flag
                        alu_op = 1; // ALU operation is SUB
                    end
                    OP_AND_imm: begin
                        w_v = 0;
                        alu_op = 4; // ALU operation is AND
                    end
                    OP_ORA_imm: begin
                        w_v = 0;
                        alu_op = 5; // ALU operation is OR
                    end
                    OP_EOR_imm: begin
                        w_v = 0;
                        alu_op = 6; // ALU operation is EOR
                    end
                    default: begin
                        w_v = 0;
                        alu_op = 0;
                    end
                endcase
                w_c = 1;            // write C flag
                w_i = 0;
                w_d = 0;
                w_z = 1;            // write Z flag
                w_n = 1;            // write N flag
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 1;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;       // carry from flags for ALU ADC/SBC operations
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;      // source ALU A is A
                src_alu_b = 0;      // source ALU B is data_in
            end
            Load: begin
                // Logic for handling load from memory
                case (inst)
                    OP_LDA_abs: begin
                        // Load Accumulator with memory
                        w_a = 1;        // write A register
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDX_abs: begin
                        // Load X register with Immediate
                        w_a = 0;
                        w_x = 1;        // write X register
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDY_abs: begin
                        // Load Y register with Immediate
                        w_a = 0;
                        w_x = 0;
                        w_y = 1;        // write Y register
                        src_alu_a = 0;  // source ALU A is A
                        src_alu_b = 0;  // source ALU B is data_in
                        alu_op = 3;     // ALU operation is pass B
                    end
                    default: begin
                        w_a = 0;                  
                        w_x = 0;
                        w_y = 0; 
                        src_alu_a = 0;
                        src_alu_b = 0;
                        alu_op = 0; 
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 0;    // write next PC high byte
                w_next_pc_l = 0;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 1;     // source address high byte is from memory
                src_addr_l = 1;     // source address low byte is from memory
            end
            FetchLoByte: begin
                // Logic for handling low byte of absolute
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 1;     // write low byte of absolute address
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            FetchHiByte: begin
                // Logic for handling high byte of absolute
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_high_byte = 1;    // write high byte of absolute address
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            Store: begin
                // Logic for handling store instruction
                case (inst)
                    OP_STA_abs: begin
                        // Store A to memory
                        src_alu_a = 0;  // source ALU A is A register
                    end
                    OP_STX_abs: begin
                        // Store X to memory
                        src_alu_a = 1;  // source ALU A is X register
                    end
                    OP_STY_abs: begin
                        // Store Y to memory
                        src_alu_a = 2;  // source ALU A is Y register
                    end
                    default: begin
                        src_alu_a = 0;
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 1;          // write to memory ALU result
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_b = 0;
                alu_op = 2;         // ALU operation is pass A
            end
            Bit: begin
                // Logic for handling BIT absolute
                w_c = 0;
                w_i = 0;
                w_v = 1;            // write V flag
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_a = 0;      // source ALU A is A register
                src_alu_b = 0;      // source ALU B is data_in
                alu_op = 7;         // ALU operation is BIT
            end
            JmpAbs: begin
                // Logic for handling high byte of JMP absolute
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 1;  // source next PC low byte is low_byte
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            Branch: begin
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 1;     // write low byte - branch offset
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            BranchTaken: begin
                // Logic for handling branch taken
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 1;    // write next PC low byte
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_next_pc_h = 0;
                src_next_pc_l = 2;  // source next PC low byte is ALU result
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 4;      // source ALU A is PC low byte
                src_alu_b = 1;      // source ALU B is low byte
                alu_op = 12;        // ALU operation: CORR
            end
            BranchCrossInc: begin
                // Logic for handling branch taken with +1 page
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_next_pc_h = 2;  // source next PC low byte is ALU result
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 5;      // source ALU A is PC hi byte
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 0;         // ALU operation: ADD
            end
            BranchCrossDec: begin
                // Logic for handling branch taken with -1 page
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_next_pc_h = 2;  // source next PC low byte is ALU result
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 5;      // source ALU A is PC hi byte
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 1;         // ALU operation: SUB
            end
            Transfer: begin
                // Transfer state logic
                case (inst)
                    OP_TXA: begin
                        // Transfer X to A
                        w_a = 1;        // save A
                        w_y = 0;
                        w_x = 0;
                        src_alu_a = 1;  // source ALU A is X register
                    end
                    OP_TAY: begin
                        // Transfer A to Y
                        w_a = 0;
                        w_y = 1;        // save Y
                        w_x = 0;
                        src_alu_a = 0;  // source ALU A is A register
                    end
                    OP_TYA: begin
                        // Transfer Y to A
                        w_a = 1;        // save A
                        w_y = 0;
                        w_x = 0;
                        src_alu_a = 2;  // source ALU A is Y register
                    end
                    OP_TSX: begin
                        // Transfer Stack Pointer to X
                        w_a = 0;
                        w_x = 1;        // save X
                        w_y = 0;
                        src_alu_a = 3;  // source ALU A is S register
                    end
                    OP_TAX: begin
                        // Transfer A to X
                        w_a = 0;
                        w_x = 1;        // save X
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A register
                    end
                    default: begin
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_b = 0;
                alu_op = 2;         // ALU operation is pass A
            end
            TransferStack: begin
                // TXS
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 1;     // source ALU A is X register
                src_alu_b = 0;
                alu_op = 2;         // ALU operation is pass A
            end
            default: begin
                // Default state logic
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_inst = 0;
                w_high_byte = 0;
                w_low_byte = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
        endcase
    end

endmodule
