
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_011_st_abs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/011_st_abs.tv";
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
        $dumpfile("tb_011_st_abs.vcd");
        $dumpvars(0, tb_011_st_abs);
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
                6: begin
                    // check STA abs
                    if (db_device.memory.data[16'h0200] !== 8'h15)
                        $error("TEST FAILED: STA ABS"); 
                end
                8: begin
                    // check LDX imm
                    if (db_device.cpu.x !== 8'h16)
                        $error("TEST FAILED: LDX IMM"); 
                end
                12: begin
                    // check STX abs
                    if (db_device.memory.data[16'h0200] !== 8'h16)
                        $error("TEST FAILED: STX ABS"); 
                end
                14: begin
                    // check LDY imm
                    if (db_device.cpu.y !== 8'h17)
                        $error("TEST FAILED: LDY IMM"); 
                end
                18: begin
                    // check STY abs
                    if (db_device.memory.data[16'h0200] !== 8'h17)
                        $error("TEST FAILED: STY ABS"); 
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
