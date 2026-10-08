
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */


    
module tb_010_bvc;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/010_bvc.tv";
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
        $dumpfile("tb_010_bvc.vcd");
        $dumpvars(0, tb_010_bvc);
        #1 rst_n = 0; #1; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 60 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                6: begin
                    // check BVC is not taken
                    if (db_device.cpu.pc_l !== 8'h05)
                        $error("TEST FAILED: BVC not taken"); 
                end
                11: begin
                    // check BVC is taken
                    if (db_device.cpu.pc_l !== 8'h0a)
                        $error("TEST FAILED: BVC taken"); 
                end
                22: begin
                    // check BVC is not taken
                    if (db_device.cpu.pc_l !== 8'h16)
                        $error("TEST FAILED: BVC not taken"); 
                end
                27: begin
                    // check BVC is taken
                    if (db_device.cpu.pc_l !== 8'h0e)
                        $error("TEST FAILED: BVC taken"); 
                end
                36: begin
                    // check BVC is not taken
                    if (db_device.cpu.pc_l !== 8'hfa)
                        $error("TEST FAILED: BVC not taken"); 
                end
                42: begin
                    // check BVC is taken
                    if (db_device.cpu.pc_l !== 8'h14 || db_device.cpu.pc_h !== 8'h05)
                        $error("TEST FAILED: BVC up cross taken"); 
                end
                46: begin
                    // check BVC is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BVC down cross taken"); 
                end
                52: begin
                    // check BVC is taken
                    if (db_device.cpu.pc_l !== 8'hfd || db_device.cpu.pc_h !== 8'h04)
                        $error("TEST FAILED: BVC infinite loop"); 
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
