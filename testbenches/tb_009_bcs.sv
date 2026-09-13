
`include "devboard.sv"

/* verilator lint_off STMTDLY */


    
module tb_009_bcs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/009_bcs.tv";
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
        $dumpfile("tb_009_bcs.vcd");
        $dumpvars(0, tb_009_bcs);
        #1 rst = 0; #1; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 60; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check BCS is not taken
                    if (db_device.cpu.pc_l !== 8'h03)
                        $error("TEST FAILED: BCS not taken"); 
                end
                9: begin
                    // check BCS is taken
                    if (db_device.cpu.pc_l !== 8'h08)
                        $error("TEST FAILED: BCS taken"); 
                end
                18: begin
                    // check BCS is not taken
                    if (db_device.cpu.pc_l !== 8'h12)
                        $error("TEST FAILED: BCS not taken"); 
                end
                23: begin
                    // check BCS is taken
                    if (db_device.cpu.pc_l !== 8'h0c)
                        $error("TEST FAILED: BCS taken"); 
                end
                30: begin
                    // check BCS is not taken
                    if (db_device.cpu.pc_l !== 8'hf4)
                        $error("TEST FAILED: BCS not taken"); 
                end
                36: begin
                    // check BCS is taken
                    if (db_device.cpu.pc_l !== 8'h0e || db_device.cpu.pc_h !== 8'h05)
                        $error("TEST FAILED: BCS up cross taken"); 
                end
                40: begin
                    // check BCS is taken
                    if (db_device.cpu.pc_l !== 8'hf7 || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BCS down cross taken"); 
                end
                43: begin
                    // check BCS is taken
                    if (db_device.cpu.pc_l !== 8'hf7 || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BCS infinite loop"); 
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
