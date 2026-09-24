
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_025_ld_abs_xy;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/025_ld_abs_xy.tv";
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
        $dumpfile("tb_025_ld_abs_xy.vcd");
        $dumpvars(0, tb_025_ld_abs_xy);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 60; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                6: begin
                    // check LDA abs,x
                    if (db_device.cpu.a !== 8'h0e)
                        $error("TEST FAILED: LDA ABS,X"); 
                end
                13: begin
                    // check LDA abs,x, page crossing
                    if (db_device.cpu.a !== 8'h10)
                        $error("TEST FAILED: LDA ABS,X"); 
                end
                19: begin
                    // check LDA abs, y
                    if (db_device.cpu.a !== 8'h0e)
                        $error("TEST FAILED: LDA ABS,Y"); 
                end
                26: begin
                    // check LDA abs, y, page crossing
                    if (db_device.cpu.a !== 8'h10)
                        $error("TEST FAILED: LDA ABS,Y"); 
                end
                32: begin
                    // check LDY abs, x
                    if (db_device.cpu.y !== 8'h0e)
                        $error("TEST FAILED: LDY ABS,X"); 
                end
                39: begin
                    // check LDY abs, x, page crossing
                    if (db_device.cpu.y !== 8'h10)
                        $error("TEST FAILED: LDY ABS,X"); 
                end
                45: begin
                    // check LDX abs, y
                    if (db_device.cpu.x !== 8'h0e)
                        $error("TEST FAILED: LDX ABS,Y"); 
                end
                52: begin
                    // check LDX abs, y, page crossing
                    if (db_device.cpu.x !== 8'h10)
                        $error("TEST FAILED: LDX ABS,Y"); 
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
