
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */


    
module tb_005_beq;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/005_beq.tv";
    logic clk;
    logic rst_n;

    devboard #(
        .MEM_FILE(MEM_FILE),
        .PC_START(16'h0400)
    )
    db_device
    (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        $dumpfile("tb_005_beq.vcd");
        $dumpvars(0, tb_005_beq);
        #1 rst_n = 0; #1; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 60 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                4: begin
                    // check BEQ is not taken
                    if (db_device.cpu.pc_l !== 8'h04)
                        $error("TEST FAILED: BEQ not taken"); 
                end
                9: begin
                    // check BEQ is taken
                    if (db_device.cpu.pc_l !== 8'h0a)
                        $error("TEST FAILED: BEQ taken"); 
                end
                18: begin
                    // check BEQ is not taken
                    if (db_device.cpu.pc_l !== 8'h15)
                        $error("TEST FAILED: BEQ not taken"); 
                end
                23: begin
                    // check BEQ is taken
                    if (db_device.cpu.pc_l !== 8'h0e)
                        $error("TEST FAILED: BEQ taken"); 
                end
                30: begin
                    // check BEQ is not taken
                    if (db_device.cpu.pc_l !== 8'hf9)
                        $error("TEST FAILED: BEQ not taken"); 
                end
                36: begin
                    // check BEQ is taken
                    if (db_device.cpu.pc_l !== 8'h14 || db_device.cpu.pc_h !== 8'h05)
                        $error("TEST FAILED: BEQ up cross taken"); 
                end
                40: begin
                    // check BEQ is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BEQ down cross taken"); 
                end
                43: begin
                    // check BEQ is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BEQ infinite loop"); 
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
