

module main_fsm (
    input logic         clk,
    input logic         rst,
    input logic [7:0]   imm,
    input logic [7:0]   alu_result,
    input logic [7:0]   flags,
    input logic         c,
    input logic         v,
    output logic        w_c,
    output logic        w_z,
    output logic        w_i,
    output logic        w_d,
    output logic        w_b,
    output logic        w_v,
    output logic        w_n,
    output logic        w_next_pc_h,
    output logic        w_next_pc_l,
    output logic        w_a,
    output logic        w_x,
    output logic        w_y,
    output logic        w_s,
    output logic        w_mem,
    output logic [1:0]  src_c_in, // TODO: check later if it really needs
    output logic [2:0]  src_data_out,
    output logic [1:0]  src_next_pc_h,
    output logic [1:0]  src_next_pc_l,
    output logic [2:0]  src_addr_h,
    output logic [2:0]  src_addr_l,
    output logic [3:0]  src_alu_a,
    output logic [2:0]  src_alu_b,
    output logic [4:0]  alu_op,
    output logic [7:0]  temp,
    output logic [7:0]  high_byte,
    output logic [7:0]  low_byte,
    output logic        undef
);
  typedef enum logic [5:0] {
        Fetch,          // Fetch
        FetchData,      // Fetch data from memory to tmp register
        WriteFakeData,  // Write fake data to memory
        LoadFlags,      // LoadFlags for CLC, SEC, CLI, SEI, CLV, CLD, SED
        LoadCmpImm,     // Load/Compare immediate with A, X, or Y
        AluTemp,        // Arithmetic/Logic (ASL, LSR, ROL, ROR) with temp
        AluAcc,         // Arithmetic/Logic (ASL, LSR, ROL, ROR) with accumulator
        AluImm,         // Arithmetic/Logic (ADC, SBC, AND, ORA, EOR) with immediate 
        FetchLoByte,    // Fetch low byte of absolute address
        FetchHiByte,    // Fetch high byte of absolute address, and add X or Y to the address low
        FetchLoByteInd, // Fetch low byte of indirect address
        FetchHiByteInd, // Fetch high byte of indirect address
        FetchHiByteIndY,// Fetch high byte of indirect address, and add Y to the address low
        AddXY,          // Add X or Y to the address low
        Store,          // Store value of A to memory
        LoadCmp,        // Load/Compare memory with A, X, or Y
        Bit,            // Handle BIT instruction
        JmpAbs,         // Handle high byte of JMP absolute
        JmpIndLowByte,  // Handle low byte of JMP indirect
        JmpInd,         // Handle high byte of JMP indirect
        Branch,         // Handle branch instructions (BNE, BEQ)
        BranchTaken,    // Handle branch taken
        BranchPageInc,  // Handle branch taken with +1 page
        BranchPageDec,  // Handle branch taken with -1 page
        Transfer,       // Handle transfer instructions (TSX, TAX, TXA, TAY, TYA)
        TransferStack,  // Handle transfer instructions TXS
        IncDec,         // Handle inc and dec instructions (INX, INY, DEX, DEY)
        Skip,           // Handle skip one cycle
        BrkFlags,       // Handle flags for BRK instruction
        Push,           // Handle push instructions (PHA, PHP)
        Pull,           // Handle pull instructions (PLA, PLP)
        PushPCHigh,     // Handle push PC high byte
        PushPCLow,      // Handle push PC low byte
        PullPCLow,      // Handle pull PC low byte
        PullPCHigh,     // Handle pull PC high byte
        FetchVectorLow, // Handle fetching low byte of interrupt vector
        FetchVectorHigh,// Handle fetching high byte of interrupt vector
        PCInc,          // Handle PC increment
        Jsr,            // Handle JSR instruction
        PullInc,        // Handle S increment
        PullInc2,       // Handle S increment again
        PageInc,        // Handle page increment addition X or Y
        Nothing         // do nothing for NOP
    } state_t;

    state_t state;
    logic c_flag;
    logic z_flag;
    logic v_flag;
    logic n_flag;

    logic [7:0] inst;

    assign c_flag = flags[0];
    assign z_flag = flags[1];
    assign v_flag = flags[6];
    assign n_flag = flags[7];

    parameter OP_BRK        = 8'h00;
    parameter OP_ORA_IND_X  = 8'h01;
    parameter OP_ORA_ZP     = 8'h05;
    parameter OP_ASL_ZP     = 8'h06;
    parameter OP_PHP        = 8'h08;
    parameter OP_ORA_IMM    = 8'h09;
    parameter OP_ASL        = 8'h0A;
    parameter OP_ORA_ABS    = 8'h0D;
    parameter OP_ASL_ABS    = 8'h0E;
    parameter OP_BPL        = 8'h10;
    parameter OP_ORA_IND_Y  = 8'h11;
    parameter OP_ORA_ZP_X   = 8'h15;
    parameter OP_ASL_ZP_X   = 8'h16;
    parameter OP_CLC        = 8'h18;
    parameter OP_ORA_ABS_Y  = 8'h19;
    parameter OP_ORA_ABS_X  = 8'h1D;
    parameter OP_ASL_ABS_X  = 8'h1E;
    parameter OP_JSR        = 8'h20;
    parameter OP_AND_IND_X  = 8'h21;
    parameter OP_BIT_ZP     = 8'h24;
    parameter OP_AND_ZP     = 8'h25;
    parameter OP_ROL_ZP     = 8'h26;
    parameter OP_PLP        = 8'h28;
    parameter OP_AND_IMM    = 8'h29;
    parameter OP_ROL        = 8'h2A;
    parameter OP_BIT_ABS    = 8'h2C;
    parameter OP_AND_ABS    = 8'h2D;
    parameter OP_ROL_ABS    = 8'h2E;
    parameter OP_BMI        = 8'h30;
    parameter OP_AND_IND_Y  = 8'h31;
    parameter OP_AND_ZP_X   = 8'h35;
    parameter OP_ROL_ZP_X   = 8'h36;
    parameter OP_SEC        = 8'h38;
    parameter OP_AND_ABS_Y  = 8'h39;
    parameter OP_AND_ABS_X  = 8'h3D;
    parameter OP_ROL_ABS_X  = 8'h3E;
    parameter OP_RTI        = 8'h40;
    parameter OP_EOR_IND_X  = 8'h41;
    parameter OP_EOR_ZP     = 8'h45;
    parameter OP_LSR_ZP     = 8'h46;
    parameter OP_PHA        = 8'h48;
    parameter OP_EOR_IMM    = 8'h49;
    parameter OP_LSR        = 8'h4A;
    parameter OP_JMP_ABS    = 8'h4C;
    parameter OP_EOR_ABS    = 8'h4D;
    parameter OP_LSR_ABS    = 8'h4E;
    parameter OP_BVC        = 8'h50;
    parameter OP_EOR_IND_Y  = 8'h51;
    parameter OP_EOR_ZP_X   = 8'h55;
    parameter OP_LSR_ZP_X   = 8'h56;
    parameter OP_CLI        = 8'h58;
    parameter OP_EOR_ABS_Y  = 8'h59;
    parameter OP_EOR_ABS_X  = 8'h5D;
    parameter OP_LSR_ABS_X  = 8'h5E;
    parameter OP_RTS        = 8'h60;
    parameter OP_ADC_IND_X  = 8'h61;
    parameter OP_ADC_ZP     = 8'h65;
    parameter OP_ROR_ZP     = 8'h66;
    parameter OP_PLA        = 8'h68;
    parameter OP_ADC_IMM    = 8'h69;
    parameter OP_ROR        = 8'h6A;
    parameter OP_JMP_IND    = 8'h6C;
    parameter OP_ADC_ABS    = 8'h6D;
    parameter OP_ROR_ABS    = 8'h6E;
    parameter OP_BVS        = 8'h70;
    parameter OP_ADC_IND_Y  = 8'h71;
    parameter OP_ADC_ZP_X   = 8'h75;
    parameter OP_ROR_ZP_X   = 8'h76;
    parameter OP_SEI        = 8'h78;
    parameter OP_ADC_ABS_Y  = 8'h79;
    parameter OP_ADC_ABS_X  = 8'h7D;
    parameter OP_ROR_ABS_X  = 8'h7E;
    parameter OP_STA_IND_X  = 8'h81;
    parameter OP_STY_ZP     = 8'h84;
    parameter OP_STA_ZP     = 8'h85;
    parameter OP_STX_ZP     = 8'h86;
    parameter OP_DEY        = 8'h88;
    parameter OP_TXA        = 8'h8A;
    parameter OP_STY_ABS    = 8'h8C;
    parameter OP_STA_ABS    = 8'h8D;
    parameter OP_STX_ABS    = 8'h8E;
    parameter OP_BCC        = 8'h90;
    parameter OP_STA_IND_Y  = 8'h91;
    parameter OP_STY_ZP_X   = 8'h94;
    parameter OP_STA_ZP_X   = 8'h95;
    parameter OP_STX_ZP_Y   = 8'h96;
    parameter OP_TYA        = 8'h98;
    parameter OP_STA_ABS_Y  = 8'h99;
    parameter OP_STA_ABS_X  = 8'h9D;
    parameter OP_TXS        = 8'h9A;
    parameter OP_LDY_IMM    = 8'hA0;
    parameter OP_LDA_IND_X  = 8'hA1;
    parameter OP_LDX_IMM    = 8'hA2;
    parameter OP_LDY_ZP     = 8'hA4;
    parameter OP_LDA_ZP     = 8'hA5;
    parameter OP_LDX_ZP     = 8'hA6;
    parameter OP_TAY        = 8'hA8;
    parameter OP_LDA_IMM    = 8'hA9;
    parameter OP_TAX        = 8'hAA;
    parameter OP_LDY_ABS    = 8'hAC;
    parameter OP_LDX_ABS    = 8'hAE;
    parameter OP_LDA_ABS    = 8'hAD;
    parameter OP_BCS        = 8'hB0;
    parameter OP_LDA_IND_Y  = 8'hB1;
    parameter OP_LDY_ZP_X   = 8'hB4;
    parameter OP_LDA_ZP_X   = 8'hB5;    
    parameter OP_LDX_ZP_Y   = 8'hB6;
    parameter OP_CLV        = 8'hB8;
    parameter OP_LDA_ABS_Y  = 8'hB9;
    parameter OP_TSX        = 8'hBA;
    parameter OP_LDY_ABS_X  = 8'hBC;
    parameter OP_LDA_ABS_X  = 8'hBD;
    parameter OP_LDX_ABS_Y  = 8'hBE;
    parameter OP_CPY_IMM    = 8'hC0;
    parameter OP_CMP_IND_X  = 8'hC1;
    parameter OP_CPY_ZP     = 8'hC4;
    parameter OP_CMP_ZP     = 8'hC5;
    parameter OP_DEC_ZP     = 8'hC6;
    parameter OP_INY        = 8'hC8;
    parameter OP_CMP_IMM    = 8'hC9;
    parameter OP_DEX        = 8'hCA;
    parameter OP_CPY_ABS    = 8'hCC;
    parameter OP_CMP_ABS    = 8'hCD;
    parameter OP_DEC_ABS    = 8'hCE;
    parameter OP_BNE        = 8'hD0;
    parameter OP_CMP_IND_Y  = 8'hD1;
    parameter OP_CMP_ZP_X   = 8'hD5;
    parameter OP_DEC_ZP_X   = 8'hD6;
    parameter OP_CLD        = 8'hD8;
    parameter OP_CMP_ABS_Y  = 8'hD9;
    parameter OP_CMP_ABS_X  = 8'hDD;
    parameter OP_DEC_ABS_X  = 8'hDE;
    parameter OP_CPX_IMM    = 8'hE0;
    parameter OP_SBC_IND_X  = 8'hE1;
    parameter OP_CPX_ZP     = 8'hE4;
    parameter OP_SBC_ZP     = 8'hE5;
    parameter OP_INC_ZP     = 8'hE6;
    parameter OP_INX        = 8'hE8;
    parameter OP_SBC_IMM    = 8'hE9;
    parameter OP_NOP        = 8'hEA;
    parameter OP_CPX_ABS    = 8'hEC;
    parameter OP_SBC_ABS    = 8'hED;
    parameter OP_INC_ABS    = 8'hEE;
    parameter OP_BEQ        = 8'hF0;
    parameter OP_SBC_IND_Y  = 8'hF1;
    parameter OP_SBC_ZP_X   = 8'hF5;
    parameter OP_INC_ZP_X   = 8'hF6;
    parameter OP_SED        = 8'hF8;
    parameter OP_SBC_ABS_Y  = 8'hF9;
    parameter OP_SBC_ABS_X  = 8'hFD;
    parameter OP_INC_ABS_X  = 8'hFE;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= Fetch;
            undef <= 0;
        end else
            case (state)
            Fetch: begin
                inst <= imm;
                case (imm)
                    OP_ROR,
                    OP_ROL,
                    OP_LSR,
                    OP_ASL: 
                        state <= AluAcc;
                    OP_CLC,
                    OP_SEC,
                    OP_CLI,
                    OP_SEI,
                    OP_CLV,
                    OP_CLD,
                    OP_SED: 
                        state <= LoadFlags;
                    OP_CMP_IMM,
                    OP_CPX_IMM,
                    OP_CPY_IMM,
                    OP_LDA_IMM,
                    OP_LDX_IMM,
                    OP_LDY_IMM:
                        state <= LoadCmpImm;
                    OP_AND_IMM,
                    OP_ORA_IMM,
                    OP_EOR_IMM,
                    OP_ADC_IMM,
                    OP_SBC_IMM:
                        state <= AluImm;
                    OP_NOP:
                        state <= Nothing;
                    OP_BNE,
                    OP_BEQ,
                    OP_BPL,
                    OP_BMI,
                    OP_BCC,
                    OP_BCS,
                    OP_BVC,
                    OP_BVS:
                        state <= Branch;
                    OP_TXS:
                        state <= TransferStack;
                    OP_TSX,
                    OP_TAX,
                    OP_TXA,
                    OP_TAY,
                    OP_TYA:
                        state <= Transfer;
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X,
                    OP_CMP_IND_X,
                    OP_LDA_IND_X,
                    OP_STA_IND_X,
                    OP_ADC_IND_Y,
                    OP_SBC_IND_Y,
                    OP_AND_IND_Y,
                    OP_ORA_IND_Y,
                    OP_EOR_IND_Y,
                    OP_CMP_IND_Y,
                    OP_LDA_IND_Y,
                    OP_STA_IND_Y,
                    OP_ASL_ZP,
                    OP_LSR_ZP,
                    OP_ROL_ZP,
                    OP_ROR_ZP,
                    OP_DEC_ZP,
                    OP_INC_ZP,
                    OP_ADC_ZP,
                    OP_SBC_ZP,
                    OP_AND_ZP,
                    OP_ORA_ZP,
                    OP_EOR_ZP,
                    OP_BIT_ZP,
                    OP_CMP_ZP,
                    OP_CPX_ZP,
                    OP_CPY_ZP,
                    OP_LDA_ZP,
                    OP_LDX_ZP,
                    OP_LDY_ZP,
                    OP_STA_ZP,
                    OP_STX_ZP,
                    OP_STY_ZP,
                    OP_STX_ZP_Y,
                    OP_LDX_ZP_Y,
                    OP_ASL_ZP_X,
                    OP_LSR_ZP_X,
                    OP_DEC_ZP_X,
                    OP_INC_ZP_X,
                    OP_ROL_ZP_X,
                    OP_ROR_ZP_X,
                    OP_ADC_ZP_X,
                    OP_SBC_ZP_X,
                    OP_AND_ZP_X,
                    OP_ORA_ZP_X,
                    OP_EOR_ZP_X,
                    OP_CMP_ZP_X,
                    OP_LDA_ZP_X,
                    OP_LDY_ZP_X,
                    OP_STA_ZP_X,
                    OP_STY_ZP_X,
                    OP_JSR,
                    OP_ASL_ABS,
                    OP_LSR_ABS,
                    OP_ROL_ABS,
                    OP_ROR_ABS,
                    OP_ADC_ABS,
                    OP_SBC_ABS,
                    OP_AND_ABS,
                    OP_ORA_ABS,
                    OP_EOR_ABS,
                    OP_DEC_ABS,
                    OP_INC_ABS,
                    OP_CMP_ABS,
                    OP_CPX_ABS,
                    OP_CPY_ABS,
                    OP_BIT_ABS,
                    OP_LDA_ABS,
                    OP_LDX_ABS,
                    OP_LDY_ABS,
                    OP_STA_ABS,
                    OP_STX_ABS,
                    OP_STY_ABS,
                    OP_CMP_ABS_Y,
                    OP_LDA_ABS_Y,
                    OP_LDX_ABS_Y,
                    OP_STA_ABS_Y,
                    OP_ADC_ABS_Y,
                    OP_SBC_ABS_Y,
                    OP_AND_ABS_Y,
                    OP_ORA_ABS_Y,
                    OP_EOR_ABS_Y,
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_ADC_ABS_X,
                    OP_SBC_ABS_X,
                    OP_AND_ABS_X,
                    OP_ORA_ABS_X,
                    OP_EOR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X,
                    OP_CMP_ABS_X,
                    OP_LDA_ABS_X,
                    OP_LDY_ABS_X,
                    OP_STA_ABS_X,
                    OP_JMP_IND,
                    OP_JMP_ABS:
                        state <= FetchLoByte;
                    OP_DEX,
                    OP_INX,
                    OP_DEY,
                    OP_INY:
                        state <= IncDec;
                    OP_RTI:
                        state <= PullInc;
                    OP_BRK:
                        state <= BrkFlags;
                    OP_RTS,
                    OP_PLA,
                    OP_PLP,
                    OP_PHA,
                    OP_PHP:
                        state <= Skip;
                    default: begin
                        undef <= 1;
                        state <= Fetch;
                    end
                endcase
            end
            BrkFlags:
                state <= PushPCHigh;
            Skip:
                case (inst)
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X:
                        state <= FetchData;
                    OP_STA_IND_Y,
                    OP_STA_ABS_X,
                    OP_STA_ABS_Y:
                        state <= Store;
                    OP_JSR:
                        state <= PushPCHigh;
                    OP_RTS,
                    OP_PLA,
                    OP_PLP:
                        state <= PullInc;
                    OP_PHA,
                    OP_PHP: 
                        state <= Push;
                    default:
                        state <= Fetch;
                endcase
            PushPCHigh:
                state <= PushPCLow;
            PushPCLow:
                case (inst)
                    OP_BRK:
                        state <= Push;
                    OP_JSR:
                        state <= Jsr;
                    default:
                        state <= Fetch;
                endcase
            Push:
                case (inst)
                    OP_BRK:
                        state <= FetchVectorLow;
                    default:
                        state <= Fetch;
                endcase
            FetchVectorLow: begin
                low_byte <= imm;
                state <= FetchVectorHigh;
            end
            PullInc:
                case (inst)
                    OP_RTS:
                        state <= PullPCLow;
                    OP_RTI,
                    OP_PLA,
                    OP_PLP:
                        state <= Pull;
                    default:
                        state <= Fetch;
                endcase
            Pull:
                case (inst)
                    OP_RTI:
                        state <= PullInc2;
                    default:
                        state <= Fetch;
                endcase
            PullInc2:
                state <= PullPCLow;
            PullPCLow: begin
                low_byte <= imm;
                state <= PullPCHigh;
            end
            PullPCHigh:
                case (inst)
                    OP_RTI:
                        state <= Fetch;
                    default:
                        state <= PCInc;
                endcase
            FetchLoByte: begin
                high_byte <= 0;
                low_byte <= imm;
                case (inst)
                    OP_ASL_ZP,
                    OP_LSR_ZP,
                    OP_ROL_ZP,
                    OP_ROR_ZP,
                    OP_DEC_ZP,
                    OP_INC_ZP:
                        state <= FetchData;
                    OP_ADC_IND_Y,
                    OP_SBC_IND_Y,
                    OP_AND_IND_Y,
                    OP_ORA_IND_Y,
                    OP_EOR_IND_Y,
                    OP_STA_IND_Y,
                    OP_LDA_IND_Y,
                    OP_CMP_IND_Y:
                        state <= FetchLoByteInd;
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X,
                    OP_STA_IND_X,
                    OP_CMP_IND_X,
                    OP_LDA_IND_X,
                    OP_ASL_ZP_X,
                    OP_LSR_ZP_X,
                    OP_ROL_ZP_X,
                    OP_ROR_ZP_X,
                    OP_ADC_ZP_X,
                    OP_SBC_ZP_X,
                    OP_AND_ZP_X,
                    OP_ORA_ZP_X,
                    OP_EOR_ZP_X,
                    OP_DEC_ZP_X,
                    OP_INC_ZP_X,
                    OP_STA_ZP_X,
                    OP_STY_ZP_X,
                    OP_CMP_ZP_X,
                    OP_LDA_ZP_X,
                    OP_LDY_ZP_X,
                    OP_STX_ZP_Y,
                    OP_LDX_ZP_Y: 
                        state <= AddXY;
                    OP_JSR: 
                        state <= Skip;
                    OP_JMP_ABS:
                        state <= JmpAbs;
                    OP_STA_ZP,
                    OP_STX_ZP,
                    OP_STY_ZP:
                        state <= Store;
                    OP_BIT_ZP:
                        state <= Bit;
                    OP_ADC_ZP,
                    OP_SBC_ZP,
                    OP_AND_ZP,
                    OP_ORA_ZP,
                    OP_EOR_ZP:
                        state <= AluAcc;
                    OP_CMP_ZP,
                    OP_CPX_ZP,
                    OP_CPY_ZP,
                    OP_LDA_ZP,
                    OP_LDX_ZP,
                    OP_LDY_ZP: 
                        state <= LoadCmp;
                    OP_JMP_IND, 
                    OP_ASL_ABS,
                    OP_LSR_ABS,
                    OP_ROL_ABS,
                    OP_ROR_ABS,
                    OP_DEC_ABS,
                    OP_INC_ABS,
                    OP_ADC_ABS,
                    OP_SBC_ABS,
                    OP_AND_ABS,
                    OP_ORA_ABS,
                    OP_EOR_ABS,
                    OP_CMP_ABS,
                    OP_CPX_ABS,
                    OP_CPY_ABS,
                    OP_BIT_ABS,
                    OP_LDA_ABS,
                    OP_LDX_ABS,
                    OP_LDY_ABS,
                    OP_STA_ABS,
                    OP_STX_ABS,
                    OP_STY_ABS,
                    OP_CMP_ABS_Y,
                    OP_LDA_ABS_Y,
                    OP_LDX_ABS_Y,
                    OP_STA_ABS_Y,
                    OP_ADC_ABS_Y,
                    OP_SBC_ABS_Y,
                    OP_AND_ABS_Y,
                    OP_ORA_ABS_Y,
                    OP_EOR_ABS_Y,
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_ADC_ABS_X,
                    OP_SBC_ABS_X,
                    OP_AND_ABS_X,
                    OP_ORA_ABS_X,
                    OP_EOR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X,
                    OP_CMP_ABS_X,
                    OP_LDA_ABS_X,
                    OP_LDY_ABS_X,
                    OP_STA_ABS_X:
                        state <= FetchHiByte;
                    default:
                        state <= Fetch;
                endcase
            end
            FetchData: begin
                temp <= imm;
                state <= WriteFakeData;
            end
            WriteFakeData:
                state <= AluTemp;
            FetchHiByte: begin
                high_byte <= imm;
                case (inst)
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X,
                    OP_STA_ABS_X,
                    OP_STA_ABS_Y: begin
                        low_byte <= alu_result;
                        if (c)
                            state <= PageInc; // Increment page if page boundary is crossed
                        else
                            state <= Skip;
                    end
                    OP_ADC_ABS_Y,
                    OP_SBC_ABS_Y,
                    OP_AND_ABS_Y,
                    OP_ORA_ABS_Y,
                    OP_EOR_ABS_Y,
                    OP_ADC_ABS_X,
                    OP_SBC_ABS_X,
                    OP_AND_ABS_X,
                    OP_ORA_ABS_X,
                    OP_EOR_ABS_X: begin
                        low_byte <= alu_result;
                        if (c)
                            state <= PageInc; // Increment page if page boundary is crossed
                        else
                            state <= AluAcc;
                    end
                    OP_CMP_ABS_X,
                    OP_LDA_ABS_X,
                    OP_LDY_ABS_X,
                    OP_CMP_ABS_Y,
                    OP_LDA_ABS_Y,
                    OP_LDX_ABS_Y: begin
                        low_byte <= alu_result;
                        if (c)
                            state <= PageInc; // Increment page if page boundary is crossed
                        else
                            state <= LoadCmp;
                    end
                    OP_ASL_ABS,
                    OP_LSR_ABS,
                    OP_ROL_ABS,
                    OP_ROR_ABS,
                    OP_DEC_ABS,
                    OP_INC_ABS:
                        state <= FetchData;
                    OP_CMP_ABS,
                    OP_CPX_ABS,
                    OP_CPY_ABS,
                    OP_LDA_ABS,
                    OP_LDX_ABS,
                    OP_LDY_ABS: 
                        state <= LoadCmp;
                    OP_JMP_IND: 
                        state <= JmpIndLowByte;
                    OP_STA_ABS,
                    OP_STX_ABS,
                    OP_STY_ABS:
                        state <= Store;
                    OP_BIT_ABS:
                        state <= Bit;
                    OP_ADC_ABS,
                    OP_SBC_ABS,
                    OP_AND_ABS,
                    OP_ORA_ABS,
                    OP_EOR_ABS:
                        state <= AluAcc;
                    default:
                        state <= Fetch;
                endcase
            end
            FetchLoByteInd: begin
                temp <= imm;
                low_byte <= alu_result;
                case (inst)
                    OP_ADC_IND_Y,
                    OP_SBC_IND_Y,
                    OP_AND_IND_Y,
                    OP_ORA_IND_Y,
                    OP_EOR_IND_Y,
                    OP_STA_IND_Y,
                    OP_CMP_IND_Y,
                    OP_LDA_IND_Y:
                        state <= FetchHiByteIndY;
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X,
                    OP_STA_IND_X,
                    OP_CMP_IND_X,
                    OP_LDA_IND_X: 
                        state <= FetchHiByteInd;
                    default:
                        state <= Fetch;
                endcase
            end
            FetchHiByteIndY: begin
                high_byte <= imm;
                low_byte <= alu_result;
                if (c)
                    state <= PageInc; // Increment page if page boundary is crossed
                else
                    case (inst)
                        OP_ADC_IND_Y,
                        OP_SBC_IND_Y,
                        OP_AND_IND_Y,
                        OP_ORA_IND_Y,
                        OP_EOR_IND_Y:
                            state <= AluAcc;
                        OP_STA_IND_Y:
                            state <= Skip;
                        OP_CMP_IND_Y,
                        OP_LDA_IND_Y: 
                            state <= LoadCmp;
                        default:
                            state <= Fetch;
                    endcase
            end
            FetchHiByteInd: begin
                high_byte <= imm;
                low_byte <= alu_result;
                case (inst)
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X: 
                        state <= AluAcc;
                    OP_STA_IND_X:
                        state <= Store;
                    OP_CMP_IND_X,
                    OP_LDA_IND_X: 
                        state <= LoadCmp;
                    default:
                        state <= Fetch;
                endcase
            end
            AddXY: begin
                low_byte <= alu_result;
                case (inst)
                    OP_ADC_ZP_X,
                    OP_SBC_ZP_X,
                    OP_AND_ZP_X,
                    OP_ORA_ZP_X,
                    OP_EOR_ZP_X:
                        state <= AluAcc;
                    OP_ASL_ZP_X,
                    OP_LSR_ZP_X,
                    OP_ROL_ZP_X,
                    OP_ROR_ZP_X,
                    OP_DEC_ZP_X,
                    OP_INC_ZP_X:
                        state <= FetchData;
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X,
                    OP_STA_IND_X,
                    OP_CMP_IND_X,
                    OP_LDA_IND_X:
                        state <= FetchLoByteInd;
                    OP_STA_ZP_X,
                    OP_STY_ZP_X,
                    OP_STX_ZP_Y:
                        state <= Store;
                    OP_CMP_ZP_X,
                    OP_LDA_ZP_X,
                    OP_LDY_ZP_X,
                    OP_LDX_ZP_Y: 
                        state <= LoadCmp;
                    default:
                        state <= Fetch;
                endcase
            end
            PageInc: begin
                high_byte <= alu_result;
                case (inst)
                    OP_ADC_IND_Y,
                    OP_SBC_IND_Y,
                    OP_AND_IND_Y,
                    OP_ORA_IND_Y,
                    OP_EOR_IND_Y,
                    OP_ADC_ABS_Y,
                    OP_SBC_ABS_Y,
                    OP_AND_ABS_Y,
                    OP_ORA_ABS_Y,
                    OP_EOR_ABS_Y,
                    OP_ADC_ABS_X,
                    OP_SBC_ABS_X,
                    OP_AND_ABS_X,
                    OP_ORA_ABS_X,
                    OP_EOR_ABS_X: 
                        state <= AluAcc;
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X:
                        state <= FetchData;
                    OP_STA_IND_Y,
                    OP_STA_ABS_Y,
                    OP_STA_ABS_X:
                        state <= Store;
                    OP_CMP_IND_Y,
                    OP_LDA_IND_Y,
                    OP_CMP_ABS_Y,
                    OP_LDA_ABS_Y,
                    OP_LDX_ABS_Y,
                    OP_CMP_ABS_X,
                    OP_LDA_ABS_X,
                    OP_LDY_ABS_X:
                        state <= LoadCmp;
                    default:
                        state <= Fetch;
                endcase
            end
            JmpIndLowByte: begin
                low_byte <= alu_result;
                state <= JmpInd;
            end
            Branch: begin
                low_byte <= imm;
                state <= Fetch;
                case (inst)
                    OP_BNE:
                        if (~z_flag)    // BNE is taken if Z flag is 0
                            state <= BranchTaken;
                    OP_BEQ:
                        // BEQ
                        if (z_flag)     // BEQ is taken if Z flag is 1
                            state <= BranchTaken;
                    OP_BPL:
                        if (~n_flag)    // BPL is taken if N flag is 0
                            state <= BranchTaken;
                    OP_BMI:
                        if (n_flag)     // BMI is taken if N flag is 1
                            state <= BranchTaken;
                    OP_BCC:
                        if (~c_flag)    // BCC is taken if C flag is 0
                            state <= BranchTaken;
                    OP_BCS:
                        if (c_flag)     // BCS is taken if C flag is 1
                            state <= BranchTaken; 
                    OP_BVC:
                        if (~v_flag)    // BVC is taken if V flag is 0
                            state <= BranchTaken;
                    OP_BVS:
                        if (v_flag)     // BVS is taken if V flag is 1
                            state <= BranchTaken; 
                    default:
                        state <= Fetch;
                endcase
            end
            BranchTaken:
                // Cross page if pc_l sum overflows
                if (v) begin
                    if (c)
                        // Increment page if branch up
                        state <= BranchPageInc;
                    else
                        // Decrement page if branch down
                        state <= BranchPageDec;
                end else
                    // Branch not crossing page
                    state <= Fetch;
            default:
                state <= Fetch;
        endcase
    end

    always_comb begin 
        case (state)
            Fetch: begin
                // Fetch state logic
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte

                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
                w_b = 0;
                w_d = 0;
                w_z = 1;
                w_n = 1;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_s = 0;
                w_mem = 0;
                src_data_out = 0;
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
                w_b = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 0;
            end
            LoadCmpImm: begin
                case (inst)
                    OP_LDA_IMM: begin
                        // Load Accumulator with Immediate
                        w_c = 0;
                        w_a = 1;        // write A register
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDX_IMM: begin
                        // Load X register with Immediate
                        w_c = 0;
                        w_a = 0;
                        w_x = 1;        // write X register
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDY_IMM: begin
                        // Load Y register with Immediate
                        w_c = 0;
                        w_a = 0;
                        w_x = 0;
                        w_y = 1;        // write Y register
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_CMP_IMM: begin
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_CPX_IMM: begin
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 1;  // source ALU A is X
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_CPY_IMM: begin
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 2;  // source ALU A is Y
                        alu_op = 1;     // ALU operation is SUB
                    end
                    default: begin
                        w_c = 0;
                        w_a = 0;                  
                        w_x = 0;
                        w_y = 0; 
                        src_alu_a = 0;
                        alu_op = 0; 
                    end
                endcase
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                
                w_s = 0;
                w_mem = 0;
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_data_out = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_b = 0;      // source ALU B is data_in
            end
            AluAcc: begin
                 // Logic for handling arithmetic immediate instruction
                case (inst)
                    OP_ADC_IND_Y,
                    OP_ADC_IND_X,
                    OP_ADC_ABS_Y,
                    OP_ADC_ABS_X,
                    OP_ADC_ZP_X,
                    OP_ADC_ABS,
                    OP_ADC_ZP: begin
                        w_c = 1;        // write C flag
                        w_v = 1;        // write V flag
                        alu_op = 0;     // ALU operation is ADD
                    end
                    OP_SBC_IND_Y,
                    OP_SBC_IND_X,
                    OP_SBC_ABS_Y,
                    OP_SBC_ABS_X,
                    OP_SBC_ZP_X,
                    OP_SBC_ABS,
                    OP_SBC_ZP: begin
                        w_c = 1;        // write C flag
                        w_v = 1;        // write V flag
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_AND_IND_Y,
                    OP_AND_IND_X,
                    OP_AND_ABS_Y,
                    OP_AND_ABS_X,
                    OP_AND_ZP_X,
                    OP_AND_ABS,
                    OP_AND_ZP: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 4;     // ALU operation is AND
                    end
                    OP_ORA_IND_Y,
                    OP_ORA_IND_X,
                    OP_ORA_ABS_Y,
                    OP_ORA_ABS_X,
                    OP_ORA_ZP_X,
                    OP_ORA_ABS,
                    OP_ORA_ZP: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 5;     // ALU operation is OR
                    end
                    OP_EOR_IND_Y,
                    OP_EOR_IND_X,
                    OP_EOR_ABS_Y,
                    OP_EOR_ABS_X,
                    OP_EOR_ZP_X,
                    OP_EOR_ABS,
                    OP_EOR_ZP: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 6;     // ALU operation is EOR
                    end
                    OP_ASL: begin
                        w_c = 1;        // write C flag
                        w_v = 0;
                        alu_op = 15;    // ALU operation is ASL
                    end
                    OP_LSR: begin
                        w_c = 1;        // write C flag
                        w_v = 0;
                        alu_op = 16;    // ALU operation is LSR
                    end
                    OP_ROR: begin
                        w_c = 1;        // write C flag
                        w_v = 0;
                        alu_op = 17;    // ALU operation is ROR
                    end
                    OP_ROL: begin
                        w_c = 1;        // write C flag
                        w_v = 0;
                        alu_op = 18;    // ALU operation is ROL
                    end
                    default: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 0;
                    end
                endcase
                w_i = 0;
                w_d = 0;
                w_b = 0;
                w_z = 1;            // write Z flag
                w_n = 1;            // write N flag
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                
                w_a = 1;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;       // carry from flags for ALU ADC/SBC operations
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source address is 
                src_addr_l = 1;     // source address is low_byte
                src_alu_a = 0;      // source ALU A is A
                src_alu_b = 0;      // source ALU B is data_in
            end
            AluTemp: begin
                 // Logic for handling arithmetic with temp
                case (inst)
                    OP_DEC_ABS,
                    OP_DEC_ZP,
                    OP_DEC_ZP_X,
                    OP_DEC_ABS_X: begin
                        w_c = 0;
                        src_c_in = 2;   // carry 1 for ALU SUB operation
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_INC_ABS,
                    OP_INC_ZP,
                    OP_INC_ZP_X,
                    OP_INC_ABS_X: begin
                        w_c = 0;
                        src_c_in = 1;   // carry 0 for ALU ADD operation
                        alu_op = 0;     // ALU operation is ADD
                    end
                    OP_ASL_ABS,
                    OP_ASL_ZP,
                    OP_ASL_ZP_X,
                    OP_ASL_ABS_X: begin
                        w_c = 1;        // write C flag
                        src_c_in = 0;   // carry from flags
                        alu_op = 15;    // ALU operation is ASL
                    end
                    OP_LSR_ABS,
                    OP_LSR_ZP,
                    OP_LSR_ZP_X,
                    OP_LSR_ABS_X: begin
                        w_c = 1;        // write C flag
                        src_c_in = 0;   // carry from flags
                        alu_op = 16;    // ALU operation is LSR
                    end
                    OP_ROR_ABS,
                    OP_ROR_ZP,
                    OP_ROR_ZP_X,
                    OP_ROR_ABS_X: begin
                        w_c = 1;        // write C flag
                        src_c_in = 0;   // carry from flags
                        alu_op = 17;    // ALU operation is ROR
                    end
                    OP_ROL_ABS,
                    OP_ROL_ZP,
                    OP_ROL_ZP_X,
                    OP_ROL_ABS_X: begin
                        w_c = 1;        // write C flag
                        src_c_in = 0;   // carry from flags
                        alu_op = 18;    // ALU operation is ROL
                    end
                    default: begin
                        w_c = 0;
                        src_c_in = 0;
                        alu_op = 0;
                    end
                endcase
                w_i = 0;
                w_v = 0;
                w_d = 0;
                w_b = 0;
                w_z = 1;            // write Z flag
                w_n = 1;            // write N flag
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 1;
                src_data_out = 0;   // source for data_out is ALU result
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_a = 8;      // source ALU A is temp
                src_alu_b = 3;      // source ALU B is 1
            end
            AluImm: begin
                // Logic for handling arithmetic immediate instruction
                case (inst)
                    OP_ADC_IMM: begin
                        w_c = 1;    // write C flag
                        w_v = 1;    // write V flag
                        alu_op = 0; // ALU operation is ADD
                    end
                    OP_SBC_IMM: begin
                        w_c = 1;    // write C flag
                        w_v = 1;    // write V flag
                        alu_op = 1; // ALU operation is SUB
                    end
                    OP_AND_IMM: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 4; // ALU operation is AND
                    end
                    OP_ORA_IMM: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 5; // ALU operation is OR
                    end
                    OP_EOR_IMM: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 6; // ALU operation is EOR
                    end
                    default: begin
                        w_c = 0;
                        w_v = 0;
                        alu_op = 0;
                    end
                endcase
                w_i = 0;
                w_d = 0;
                w_b = 0;
                w_z = 1;            // write Z flag
                w_n = 1;            // write N flag
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 1;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;       // carry from flags for ALU ADC/SBC operations
                src_data_out = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;      // source ALU A is A
                src_alu_b = 0;      // source ALU B is data_in
            end
            LoadCmp: begin
                // Logic for handling load from memory
                case (inst)
                    OP_LDA_IND_X,
                    OP_LDA_IND_Y,
                    OP_LDA_ZP,
                    OP_LDA_ZP_X,
                    OP_LDA_ABS_X,
                    OP_LDA_ABS_Y,
                    OP_LDA_ABS: begin
                        // Load Accumulator from memory
                        w_c = 0;
                        w_a = 1;        // write A register
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDX_ZP,
                    OP_LDX_ZP_Y,
                    OP_LDX_ABS_Y,
                    OP_LDX_ABS: begin
                        // Load X register from memory
                        w_c = 0;
                        w_a = 0;
                        w_x = 1;        // write X register
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_LDY_ZP,
                    OP_LDY_ZP_X,
                    OP_LDY_ABS_X,
                    OP_LDY_ABS: begin
                        // Load Y register from memory
                        w_c = 0;
                        w_a = 0;
                        w_x = 0;
                        w_y = 1;        // write Y register
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_CMP_IND_X,
                    OP_CMP_IND_Y,
                    OP_CMP_ZP,
                    OP_CMP_ZP_X,
                    OP_CMP_ABS_X,
                    OP_CMP_ABS_Y,
                    OP_CMP_ABS: begin
                        // Compare Accumulator with memory
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 0;  // source ALU A is A
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_CPX_ZP,
                    OP_CPX_ABS: begin
                        // Compare X register with memory
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 1;  // source ALU A is X
                        alu_op = 1;     // ALU operation is SUB
                    end
                    OP_CPY_ZP,
                    OP_CPY_ABS: begin
                        // Compare Y register with memory
                        w_c = 1;        // write C flag
                        w_a = 0;
                        w_x = 0;
                        w_y = 0;
                        src_alu_a = 2;  // source ALU A is Y
                        alu_op = 1;     // ALU operation is SUB
                    end
                    default: begin
                        w_c = 0;
                        w_a = 0;                  
                        w_x = 0;
                        w_y = 0; 
                        src_alu_a = 0;
                        alu_op = 0; 
                    end
                endcase
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;  
                src_addr_h = 1;     // source address high byte is from memory
                src_addr_l = 1;     // source address low byte is from memory
                src_alu_b = 0;      // source ALU B is data_in
            end
            FetchLoByte: begin
                // Logic for handling low byte of absolute
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
                // also addition X or Y to low byte of absolute address
                case (inst)
                    OP_ASL_ABS_X,
                    OP_LSR_ABS_X,
                    OP_ROL_ABS_X,
                    OP_ROR_ABS_X,
                    OP_ADC_ABS_X,
                    OP_SBC_ABS_X,
                    OP_AND_ABS_X,
                    OP_ORA_ABS_X,
                    OP_EOR_ABS_X,
                    OP_DEC_ABS_X,
                    OP_INC_ABS_X,
                    OP_STA_ABS_X,
                    OP_CMP_ABS_X,
                    OP_LDA_ABS_X,
                    OP_LDY_ABS_X: begin
                        // Add X to low byte
                        src_alu_a = 1;  // source ALU A is X register
                    end
                    OP_ADC_ABS_Y,
                    OP_SBC_ABS_Y,
                    OP_AND_ABS_Y,
                    OP_ORA_ABS_Y,
                    OP_EOR_ABS_Y,
                    OP_STA_ABS_Y,
                    OP_CMP_ABS_Y,
                    OP_LDA_ABS_Y,
                    OP_LDX_ABS_Y: begin
                        // Add Y to low byte
                        src_alu_a = 2;  // source ALU A is Y register
                    end
                    default: begin
                        src_alu_a = 0;
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_b = 1;      // source ALU B is low byte of absolute address
                alu_op = 0;         // ALU operation is ADD 
            end
            FetchData: begin
                // Logic for handling fetch data
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte
                src_addr_l = 1;     // source addr is low byte
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            WriteFakeData: begin
                // Logic for handling fetch data
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 1;
                src_c_in = 0;
                src_data_out = 0;   // source data out is ALU result
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte
                src_addr_l = 1;     // source addr is low byte
                src_alu_a = 8;      // source ALU A is temp
                src_alu_b = 0;
                alu_op = 2;         // ALU operation is pass A
            end
            FetchLoByteInd: begin
                // Logic for handling low byte of indirect address
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte
                src_addr_l = 1;     // source addr is low byte
                src_alu_a = 6;      // source ALU A is low byte
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 0;         // ALU operation is ADD
            end
            FetchHiByteInd: begin
                // Logic for handling high byte of indirect address
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte
                src_addr_l = 1;     // source addr is low byte
                src_alu_a = 0;
                src_alu_b = 4;      // source ALU B is temp
                alu_op = 3;         // ALU operation is pass B
            end
            FetchHiByteIndY: begin
                // Logic for handling high byte of indirect address
                // also addition Y to low byte of absolute address
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte
                src_addr_l = 1;     // source addr is low byte
                src_alu_a = 2;      // source ALU A is Y
                src_alu_b = 4;      // source ALU B is temp
                alu_op = 0;         // ALU operation is ADD
            end
            AddXY: begin
                // Addition X or Y to low byte of absolute address
                case (inst)
                    OP_ASL_ZP_X,
                    OP_LSR_ZP_X,
                    OP_ROL_ZP_X,
                    OP_ROR_ZP_X,
                    OP_ADC_ZP_X,
                    OP_SBC_ZP_X,
                    OP_AND_ZP_X,
                    OP_ORA_ZP_X,
                    OP_EOR_ZP_X,
                    OP_DEC_ZP_X,
                    OP_INC_ZP_X,
                    OP_ADC_IND_X,
                    OP_SBC_IND_X,
                    OP_AND_IND_X,
                    OP_ORA_IND_X,
                    OP_EOR_IND_X,
                    OP_STA_IND_X,
                    OP_CMP_IND_X,
                    OP_LDA_IND_X,
                    OP_STA_ZP_X,
                    OP_STY_ZP_X,
                    OP_CMP_ZP_X,
                    OP_LDA_ZP_X,
                    OP_LDY_ZP_X: begin
                        // Add X to low byte
                        src_alu_a = 1;  // source ALU A is X register
                    end
                    OP_STX_ZP_Y,
                    OP_LDX_ZP_Y: begin
                        // Add Y to low byte
                        src_alu_a = 2;  // source ALU A is Y register
                    end
                    default: begin
                        src_alu_a = 0;
                    end
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_b = 1;      // source ALU B is low byte of absolute address
                alu_op = 0;         // ALU operation is ADD 
            end
            FetchVectorLow: begin
                // Logic for handling low byte of interrupt vector
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 4;     // source addr is high byte of irq address low byte
                src_addr_l = 4;     // source addr is low byte of irq address low byte
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            FetchVectorHigh: begin
                // Logic for handling high byte of interrupt vector
                w_c = 0;
                w_i = 1;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 1;  // source next PC low byte is low_byte
                src_addr_h = 3;     // source addr is high byte of irq address high byte
                src_addr_l = 3;     // source addr is low byte of irq address high byte
                src_alu_a = 0;
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 11;        // ALU operation is SET_I
            end
            PageInc: begin
                // Logic for handling +1 page
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;  
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 7;      // source ALU A is 
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 0;         // ALU operation: ADD
            end
            Store: begin
                // Logic for handling store instruction
                case (inst)
                    OP_STA_IND_X,
                    OP_STA_ZP_X,
                    OP_STA_ZP,
                    OP_STA_ABS: begin
                        // Store A to memory
                        src_alu_a = 0;  // source ALU A is A register
                    end
                    OP_STX_ZP_Y,
                    OP_STX_ZP,
                    OP_STX_ABS: begin
                        // Store X to memory
                        src_alu_a = 1;  // source ALU A is X register
                    end
                    OP_STY_ZP_X,
                    OP_STY_ZP,
                    OP_STY_ABS: begin
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
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 1;          // write to memory ALU result
                src_c_in = 0;
                src_data_out = 0;   // source data out is ALU result
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
                w_b = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_a = 0;      // source ALU A is A register
                src_alu_b = 0;      // source ALU B is data_in
                alu_op = 7;         // ALU operation is BIT
            end
            BrkFlags: begin
                // Logic for handling BRK instruction flags
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 1;            // write B flag
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 3;  // source ALU B is 1
                alu_op = 14;    // ALU operation is SET_B
            end
            JmpAbs: begin
                // Logic for handling high byte of JMP absolute
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 1;  // source next PC low byte is low_byte
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            JmpIndLowByte: begin
                // Logic for handling low byte of JMP indirect
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 1;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 3;  // source next PC low byte is data_in
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_a = 6;      // source ALU A is low_byte
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 0;         // ALU operation is ADD;
            end
            JmpInd: begin
                // Logic for handling high byte of JMP indirect
                w_c = 0;
                w_i = 0;
                w_b = 0;
                w_v = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 0;
                src_addr_h = 1;     // source addr is high byte of absolute address
                src_addr_l = 1;     // source addr is low byte of absolute address
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            Jsr: begin
                // Logic for handling high byte of Jsr
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 2;  // source next PC low byte is ALU result
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 4;      // source ALU A is PC low byte
                src_alu_b = 1;      // source ALU B is low byte
                alu_op = 12;        // ALU operation: CORR
            end
            BranchPageInc: begin
                // Logic for handling branch taken with +1 page
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 1;       // carry 0 for ALU ADD operation
                src_data_out = 0;
                src_next_pc_h = 2;  // source next PC low byte is ALU result
                src_next_pc_l = 0;  
                src_addr_h = 0;     // source addr is PC
                src_addr_l = 0;
                src_alu_a = 5;      // source ALU A is PC hi byte
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 0;         // ALU operation: ADD
            end
            BranchPageDec: begin
                // Logic for handling branch taken with -1 page
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_data_out = 0;
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
                w_b = 0;
                w_d = 0;
                w_z = 1;            // write Z flag from ALU
                w_n = 1;            // write N flag from ALU
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 1;     // source ALU A is X register
                src_alu_b = 0;
                alu_op = 2;         // ALU operation is pass A
            end
            PushPCHigh: begin
                // Push PC high byte onto the stack
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 1;          // write memory 
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_data_out = 3;    // source data out is PC high byte
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 3;      // source ALU A is S register
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 1;         // ALU operation: SUB
            end
            PushPCLow: begin
                // Push PC low byte onto the stack
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 1;          // write memory 
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_data_out = 4;    // source data out is PC low byte
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 3;      // source ALU A is S register
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 1;         // ALU operation: SUB
            end
            Push: begin
                // PHA / PHP
                case (inst)
                    OP_PHA:
                        src_data_out = 1;   // source data out A for memory write
                    OP_BRK,
                    OP_PHP:
                        src_data_out = 2;   // source data out Flags for memory write
                    default: 
                        src_data_out = 0;
                endcase
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 1;          // write memory 
                src_c_in = 2;       // carry 1 for ALU SUB operation
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 3;      // source ALU A is S register
                src_alu_b = 3;      // source ALU B is 1
                alu_op = 1;         // ALU operation: SUB
            end
            PullInc2,
            PullInc: begin
                // Increment S register before pull
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 0;
                src_c_in = 1;       // carry 0 for increment
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 3;      // source ALU A is S register
                src_alu_b = 3;      // source ALU B is 1 
                alu_op = 0;         // ALU operation: ADD
            end
            Pull: begin
                // PLA / PLP
                case (inst)
                    OP_PLA: begin
                        w_a = 1;        // write A register
                        w_c = 0;
                        w_i = 0;
                        w_v = 0;
                        w_d = 0;
                        alu_op = 3;     // ALU operation is pass B
                    end
                    OP_RTI,
                    OP_PLP: begin
                        w_a = 0;
                        w_c = 1;        // write C flag
                        w_i = 1;        // write I flag
                        w_v = 1;        // write V flag
                        w_d = 1;        // write D flag
                        alu_op = 13;    // ALU operation is set FLAGS
                    end
                    default: begin
                        w_a = 0;
                        w_c = 0;
                        w_i = 0;
                        w_v = 0;
                        w_d = 0;
                        alu_op = 0;
                    end
                endcase
                w_b = 0;
                w_z = 1;                // write Z flag
                w_n = 1;                // write N flag
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 0;
                src_alu_b = 0;      // source ALU B is data_in
            end
            PullPCLow: begin
                // RTS, PC low byte
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 1;            // write S register from ALU
                w_mem = 0;
                src_c_in = 1;       // carry 0 for increment
                src_data_out = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 3;      // source ALU A is S register
                src_alu_b = 3;      // source ALU B is 1 
                alu_op = 0;         // ALU operation: ADD
            end
            PullPCHigh: begin
                // RTS, PC high byte
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 1;  // source next PC high byte is imm
                src_next_pc_l = 1;  // source next PC low byte is low_byte
                src_addr_h = 2;     // source address high is 8'h01
                src_addr_l = 2;     // source address low is S register
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            PCInc: begin
                // PC increment logic
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 1;    // write next PC high byte
                w_next_pc_l = 1;    // write next PC low byte
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
                src_next_pc_h = 0;  // source next PC is PC+1
                src_next_pc_l = 0;  
                src_addr_h = 0;
                src_addr_l = 0;
                src_alu_a = 0;
                src_alu_b = 0;
                alu_op = 0;
            end
            default: begin
                // Default state logic
                w_c = 0;
                w_i = 0;
                w_v = 0;
                w_b = 0;
                w_d = 0;
                w_z = 0;
                w_n = 0;
                w_next_pc_h = 0;
                w_next_pc_l = 0;
                w_a = 0;
                w_x = 0;
                w_y = 0;
                w_s = 0;
                w_mem = 0;
                src_c_in = 0;
                src_data_out = 0;
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
