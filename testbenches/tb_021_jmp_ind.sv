
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_021_jmp_ind;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/021_jmp_ind.tv";
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
        $dumpfile("tb_021_jmp_ind.vcd");
        $dumpvars(0, tb_021_jmp_ind);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                 5: begin
                    // check JMP IND
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h06)
                        $error("TEST FAILED: JMP IND"); 
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
