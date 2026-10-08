
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_002_ld_imm;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/002_ld_imm.tv";
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
        $dumpfile("tb_002_ld_imm.vcd");
        $dumpvars(0, tb_002_ld_imm);
        #1 rst_n = 0; #(CYCLE_LEN * 2); rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                5: begin
                    // check LDA imm
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.a !== 8'h00)
                        $error("TEST FAILED: LDA IMM"); 
                end
                7: begin
                    // check LDA imm
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.a !== 8'hf5)
                        $error("TEST FAILED: LDA IMM"); 
                end
                9: begin
                     // check LDX imm
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.x !== 8'h00)
                        $error("TEST FAILED: LDX IMM"); 
                end
                11: begin
                    // check LDX imm
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.x !== 8'hf3)
                        $error("TEST FAILED: LDX IMM"); 
                end
                13: begin
                     // check LDY imm
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.y !== 8'h00)
                        $error("TEST FAILED: LDY IMM"); 
                end
                14: begin
                    // check LDY imm
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.y !== 8'hf1)
                        $error("TEST FAILED: LDY IMM"); 
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
