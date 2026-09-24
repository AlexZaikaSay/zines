
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_6502_functional_test;

    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/6502_functional_test.tv";

    integer i = 0;
    logic clk;
    logic rst;

    devboard #(
        .PC_START(16'h0400),
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
        #1; rst = 0; #(CYCLE_LEN * 2 + 1); rst = 1;
    end

    initial begin
        for (; i < 120000; i++)
        begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
        $error("TEST FAILED: reached end of simulation without passing");
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
        if (db_device.cpu.undef) 
        begin
            $error("Undefined instruction %h at address %h (clk = %0d)", db_device.cpu.data_in, db_device.cpu.addr, i);
            $finish;
        end
    end
  
endmodule

/* verilator lint_on STMTDLY */
