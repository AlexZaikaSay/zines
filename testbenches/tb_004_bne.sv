
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_004_bne;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/004_bne.tv";
    logic clk;
    logic rst;

    devboard #(
        .MEM_FILE(MEM_FILE),
        .PC_START(16'h0400)
    )
    db_device
    (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("tb_004_bne.vcd");
        $dumpvars(0, tb_004_bne);
        #1 rst = 0; #1; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 60; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check BNE is not taken
                    if (db_device.cpu.pc_l !== 8'h04)
                        $error("TEST FAILED: BNE not taken"); 
                end
                9: begin
                    // check BNE is taken
                    if (db_device.cpu.pc_l !== 8'h0a)
                        $error("TEST FAILED: BNE taken"); 
                end
                18: begin
                    // check BNE is not taken
                    if (db_device.cpu.pc_l !== 8'h15)
                        $error("TEST FAILED: BNE not taken"); 
                end
                23: begin
                    // check BNE is taken
                    if (db_device.cpu.pc_l !== 8'h0e)
                        $error("TEST FAILED: BNE taken"); 
                end
                30: begin
                    // check BNE is not taken
                    if (db_device.cpu.pc_l !== 8'hf9)
                        $error("TEST FAILED: BNE not taken"); 
                end
                36: begin
                    // check BNE is taken
                    if (db_device.cpu.pc_l !== 8'h14 || db_device.cpu.pc_h !== 8'h05)
                        $error("TEST FAILED: BNE up cross taken"); 
                end
                40: begin
                    // check BNE is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BNE down cross taken"); 
                end
                43: begin
                    // check BNE is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BNE infinite loop"); 
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
