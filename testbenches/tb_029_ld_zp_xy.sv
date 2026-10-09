
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_029_ld_zp_xy;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/029_ld_zp_xy.tv";
    logic clk;
    logic rst_n;

    devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        $dumpfile("tb_029_ld_zp_xy.vcd");
        $dumpvars(0, tb_029_ld_zp_xy);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                6: begin
                    // check LDA zp,x
                    if (db_device.cpu.a !== 8'h0e)
                        $error("TEST FAILED: LDA ZP,X"); 
                end
                12: begin
                    // check LDY zp, x
                    if (db_device.cpu.y !== 8'h0e)
                        $error("TEST FAILED: LDY ZP,X"); 
                end
                18: begin
                    // check LDX zp, y
                    if (db_device.cpu.x !== 8'h0e)
                        $error("TEST FAILED: LDX ZP,Y"); 
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
