
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_013_ld_abs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/013_ld_abs.tv";
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
        $dumpfile("tb_013_ld_abs.vcd");
        $dumpvars(0, tb_013_ld_abs);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check LDA abs
                    if (db_device.cpu.a !== 8'h0c)
                        $error("TEST FAILED: LDA ABS"); 
                end
                8: begin
                    // check LDX abs
                    if (db_device.cpu.x !== 8'h0d)
                        $error("TEST FAILED: LDX ABS"); 
                end
                12: begin
                    // check LDY abs
                    if (db_device.cpu.y !== 8'h0e)
                        $error("TEST FAILED: LDY ABS"); 
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
