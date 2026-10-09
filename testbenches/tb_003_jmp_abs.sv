
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_003_jmp_abs;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/003_jmp_abs.tv";
    logic clk;
    logic rst_n;

    devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        $dumpfile("tb_003_jmp_abs.vcd");
        $dumpvars(0, tb_003_jmp_abs);
        #1 rst_n = 0; #1; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                2: begin
                    // check NOP
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h01)
                        $error("TEST FAILED: NOP"); 
                end
                5: begin
                    // check LDA imm
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h05)
                        $error("TEST FAILED: JMP IMM"); 
                end
                default: begin
                    // No specific check for this cycle
                end
            endcase
        end
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
    end
  
endmodule

/* verilator lint_on STMTDLY */
