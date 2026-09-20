
`include "devboard.sv"

/* verilator lint_off STMTDLY */


    
module tb_011_bvs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/011_bvs.tv";
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
        $dumpfile("tb_011_bvs.vcd");
        $dumpvars(0, tb_011_bvs);
        #1 rst = 0; #1; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 60; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check BVS is not taken
                    if (db_device.cpu.pc_l !== 8'h03)
                        $error("TEST FAILED: BVS not taken"); 
                end
                11: begin
                    // check BVS is taken
                    if (db_device.cpu.pc_l !== 8'h0a)
                        $error("TEST FAILED: BVS taken"); 
                end
                20: begin
                    // check BVS is not taken
                    if (db_device.cpu.pc_l !== 8'h14)
                        $error("TEST FAILED: BVS not taken"); 
                end
                27: begin
                    // check BVS is taken
                    if (db_device.cpu.pc_l !== 8'h0e)
                        $error("TEST FAILED: BVS taken"); 
                end
                34: begin
                    // check BVS is not taken
                    if (db_device.cpu.pc_l !== 8'hf8)
                        $error("TEST FAILED: BVS not taken"); 
                end
                42: begin
                    // check BVS is taken
                    if (db_device.cpu.pc_l !== 8'h14 || db_device.cpu.pc_h !== 8'h05)
                        $error("TEST FAILED: BVS up cross taken"); 
                end
                46: begin
                    // check BVS is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BVS down cross taken"); 
                end
                52: begin
                    // check BVS is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BVS infinite loop"); 
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
