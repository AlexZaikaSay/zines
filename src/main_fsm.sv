

module main_fsm (
    input logic clk,
    input logic rst,
    input logic [7:0] op,
    input logic [7:0] inst,
    output logic c,
    output logic i,
    output logic v,
    output logic d,
    output logic w_c,
    output logic w_i,
    output logic w_v,
    output logic w_d,
    output logic w_next_pc,
    output logic w_inst,
    output logic src_addr_h,
    output logic src_addr_l,
    output logic src_next_pc_h,
    output logic src_next_pc_l
);
  typedef enum logic [3:0] {
        Fetch,      // Fetch
        StoreFlags  // CLC, SEC, CLI, SEI, CLV, CLD, SED
    } state_t;

    state_t state, next_state;

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
                casez (op)
                    8'b0??1_1000: next_state = StoreFlags; // CLC, SEC, CLI, SEI
                    8'b1011_1000: next_state = StoreFlags; // CLV
                    8'b11?1_1000: next_state = StoreFlags; // CLD, SED
                    default: next_state = Fetch;          // Default to Fetch state
                endcase
            end
            StoreFlags: begin
                next_state = Fetch;          // Default to Fetch state
            end
            default: begin
                next_state = Fetch;         // Default to Fetch state
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
                w_next_pc = 1;
                w_inst = 1;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
            end
            StoreFlags: begin
                // StoreFlags state logic
                casez (inst)
                    8'b0001_1000: begin
                        // CLC
                        c = 0;
                        w_c = 1;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    8'b0011_1000: begin
                        // SEC
                        c = 1;
                        w_c = 1;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    8'b0101_1000: begin
                        // CLI
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 1;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    8'b0111_1000: begin
                        // SEI
                        c = 0;
                        w_c = 0;
                        i = 1;
                        w_i = 1;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 0;
                    end
                    8'b1011_1000: begin
                        // CLV
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 1;
                        d = 0;
                        w_d = 0;
                    end
                    8'b1101_1000: begin
                        // CLD
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 0;
                        w_d = 1;
                    end
                    8'b1111_1000: begin
                        // SED
                        c = 0;
                        w_c = 0;
                        i = 0;
                        w_i = 0;
                        v = 0;
                        w_v = 0;
                        d = 1;
                        w_d = 1;
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
                w_next_pc = 0;
                w_inst = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
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
                w_next_pc = 0;
                w_inst = 0;
                src_next_pc_h = 0;
                src_next_pc_l = 0;
                src_addr_h = 0;
                src_addr_l = 0;
            end
        endcase
    end

endmodule
