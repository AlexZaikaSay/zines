
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_012_transfer;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/012_transfer.tv";
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
        $dumpfile("tb_012_transfer.vcd");
        $dumpvars(0, tb_012_transfer);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                6: begin
                    // check LDA imm
                    if (db_device.cpu.a !== 8'h15 || db_device.cpu.x !== 8'h16 || db_device.cpu.y !== 8'h17)
                        $error("TEST FAILED: LDr IMM"); 
                end
                8: begin
                    // check TXS
                    if (db_device.cpu.s !== 8'h16)
                        $error("TEST FAILED: TXS"); 
                end
                10: begin
                     // check TSX
                    if (db_device.cpu.x !== 8'h16)
                        $error("TEST FAILED: TSX"); 
                end
                12: begin
                     // check TAX
                    if (db_device.cpu.x !== 8'h15)
                        $error("TEST FAILED: TAX"); 
                end
                14: begin
                     // check TAY
                    if (db_device.cpu.y !== 8'h15)
                        $error("TEST FAILED: TAY"); 
                end
                16: begin
                     // check TYA
                    if (db_device.cpu.a !== 8'h15)
                        $error("TEST FAILED: TYA"); 
                end
                18: begin
                     // check TXA
                    if (db_device.cpu.a !== 8'h15)
                        $error("TEST FAILED: TXA"); 
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
