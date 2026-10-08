
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_031_st_abs_xy;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/031_st_abs_xy.tv";
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
        $dumpfile("tb_031_st_abs_xy.vcd");
        $dumpvars(0, tb_031_st_abs_xy);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 32 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                9: begin
                    // check STA abs, x
                    if (db_device.memory.data[16'h0202] !== 8'h15)
                        $error("TEST FAILED: STA ABS, X"); 
                end
                16: begin
                    // check STA abs, x
                    if (db_device.memory.data[16'h0301] !== 8'h15)
                        $error("TEST FAILED: STA ABS, Y"); 
                end
                23: begin
                    // check STA abs, y
                    if (db_device.memory.data[16'h0201] !== 8'h15)
                        $error("TEST FAILED: STA ABS, Y"); 
                end
                30: begin
                    // check STA abs, y
                    if (db_device.memory.data[16'h0300] !== 8'h15)
                        $error("TEST FAILED: STA ABS, Y"); 
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
