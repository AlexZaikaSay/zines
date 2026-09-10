
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_6502_functional_test;

    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/tb_6502_functional_test.tv";
    logic clk;
    logic rst;

    devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .rst(rst)
    );

    initial begin
        $dumpfile("tb_6502_functional_test.vcd");
        $dumpvars(0, tb_6502_functional_test);
        rst = 0; #(CYCLE_LEN * 2 + 1); rst = 1;
    end

    initial begin
        for (integer i = 0; i < 200; i++)
        begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $fatal(1, "TEST FAILED: reached end of simulation without passing");
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
    end
  
endmodule

/* verilator lint_on STMTDLY */
