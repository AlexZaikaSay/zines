
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_024_st_zp;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/024_st_zp.tv";
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
        $dumpfile("tb_024_st_zp.vcd");
        $dumpvars(0, tb_024_st_zp);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                2: begin
                    // check LDA imm
                    if (db_device.cpu.a !== 8'h15)
                        $error("TEST FAILED: LDA IMM"); 
                end
                5: begin
                    // check STA zp
                    if (db_device.memory.data[16'h0000] !== 8'h15)
                        $error("TEST FAILED: STA ZP"); 
                end
                7: begin
                    // check LDX imm
                    if (db_device.cpu.x !== 8'h16)
                        $error("TEST FAILED: LDX IMM"); 
                end
                10: begin
                    // check STX zp
                    if (db_device.memory.data[16'h0000] !== 8'h16)
                        $error("TEST FAILED: STX ZP"); 
                end
                12: begin
                    // check LDY imm
                    if (db_device.cpu.y !== 8'h17)
                        $error("TEST FAILED: LDY IMM"); 
                end
                15: begin
                    // check STY zp
                    if (db_device.memory.data[16'h0000] !== 8'h17)
                        $error("TEST FAILED: STY ZP"); 
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
