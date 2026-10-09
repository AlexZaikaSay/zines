
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_028_cmp_zp;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/028_cmp_zp.tv";
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
        $dumpfile("tb_028_cmp_zp.vcd");
        $dumpvars(0, tb_028_cmp_zp);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 30 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                5: begin
                    // check CMP zp
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CMP ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                8: begin
                    // check CMP zp
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: CMP ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                13: begin
                    // check CPX zp
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CPX ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                16: begin
                    // check CPX zp
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: CPX ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                21: begin
                    // check CPY zp
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CPY ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                24: begin
                    // check CPY zp
                    if (db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: CPY ZP, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
