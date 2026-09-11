
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_001_cld;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/001_cld.tv";
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
        $dumpfile("tb_001_cld.vcd");
        $dumpvars(0, tb_001_cld);
        #1 rst = 0; #(CYCLE_LEN * 2); rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $error("TEST FAILED: reached end of simulation without passing");
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
    end
  
endmodule

/* verilator lint_on STMTDLY */
