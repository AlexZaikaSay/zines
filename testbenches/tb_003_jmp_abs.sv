
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_003_jmp_abs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/003_jmp_abs.tv";
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
        $dumpfile("tb_003_jmp_abs.vcd");
        $dumpvars(0, tb_003_jmp_abs);
        #1 rst = 0; #1; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                2: begin
                    // check NOP
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h01)
                        $error("TEST FAILED: NOP"); 
                end
                5: begin
                    // check LDA imm
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h05)
                        $error("TEST FAILED: JMP IMM"); 
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
