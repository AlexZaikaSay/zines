
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_042_asl_lsr_ror_rol_abs;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/042_asl_lsr_ror_rol_abs.tv";
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
        $dumpfile("tb_042_asl_lsr_ror_rol_abs.vcd");
        $dumpvars(0, tb_042_asl_lsr_ror_rol_abs);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 24 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                6: begin
                    // check ASL abs
                    if (db_device.memory.data[16'h0200] !== 8'h54 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h1)
                        $error("TEST FAILED: ASL ABS mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0200], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                12: begin
                    // check LSR abs
                    if (db_device.memory.data[16'h0200] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: LSR ABS mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0200], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end            
                18: begin
                    // check ROR abs
                    if (db_device.memory.data[16'h0200] !== 8'h15 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROR ABS mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0200], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                24: begin
                    // check ROL abs
                    if (db_device.memory.data[16'h0200] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROL ABS mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0200], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
