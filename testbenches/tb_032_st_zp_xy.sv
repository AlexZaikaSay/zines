
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_032_st_zp_xy;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/032_st_zp_xy.tv";
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
        $dumpfile("tb_032_st_zp_xy.vcd");
        $dumpvars(0, tb_032_st_zp_xy);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 32; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                10: begin
                    // check STA zp, x
                    if (db_device.memory.data[16'h0001] !== 8'h15)
                        $error("TEST FAILED: STA ZP, X"); 
                end
                16: begin
                    // check STX zp, y
                    if (db_device.memory.data[16'h0000] !== 8'h16)
                        $error("TEST FAILED: STX ZP, Y"); 
                end
                24: begin
                    // check STY zp, x
                    if (db_device.memory.data[16'h0002] !== 8'h17)
                        $error("TEST FAILED: STY ZP, X"); 
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
