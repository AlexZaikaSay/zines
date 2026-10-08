
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_073_reset;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/073_reset.tv";
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
        $dumpfile("tb_073_reset.vcd");
        $dumpvars(0, tb_073_reset);
        #1 rst_n = 0; #2; rst_n = 1;
        #81; rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                7,
                15: begin
                    // reset
                    if (db_device.cpu.pc_l !== 8'h00  || db_device.cpu.pc_h !== 8'h04 || db_device.cpu.flags !== 8'h66)
                        $error("TEST FAILED: RESET, pc_l=%h, pc_h=%h, flags=%h", db_device.cpu.pc_l, db_device.cpu.pc_h, db_device.cpu.flags); 
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
