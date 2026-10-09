
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_014_inc_dec_reg;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/014_inc_dec_reg.tv";
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
        $dumpfile("tb_014_inc_dec_reg.vcd");
        $dumpvars(0, tb_014_inc_dec_reg);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                4: begin
                    // check LDA imm
                    if (db_device.cpu.x !== 8'h0 || db_device.cpu.y !== 8'h0)
                        $error("TEST FAILED: LDA IMM"); 
                end
                6: begin
                    // check DEX
                    if (db_device.cpu.x !== 8'hff || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: DEX"); 
                end
                8: begin
                    // check INX
                    if (db_device.cpu.x !== 8'h0 || db_device.cpu.flags[1] !== 1'h1 || db_device.cpu.flags[7] !== 1'h0)
                        $error("TEST FAILED: INX"); 
                end
                10: begin
                    // check DEY
                    if (db_device.cpu.y !== 8'hff || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: DEY"); 
                end
                12: begin
                    // check INY
                    if (db_device.cpu.y !== 8'h0 || db_device.cpu.flags[1] !== 1'h1 || db_device.cpu.flags[7] !== 1'h0)
                        $error("TEST FAILED: INY"); 
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
