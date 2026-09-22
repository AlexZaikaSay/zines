
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_019_push_pull;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/019_push_pull.tv";
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
        $dumpfile("tb_019_push_pull.vcd");
        $dumpvars(0, tb_019_push_pull);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 48; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                9: begin
                    // check PHA #1
                    if (db_device.cpu.s !== 8'hfe || db_device.memory.data[16'h01ff] !== 8'h01)
                        $error("TEST FAILED: PHA, s=%h, mem[01ff]=%h", db_device.cpu.s, db_device.memory.data[16'h01ff]); 
                end
                12: begin
                    // check PHP
                    if (db_device.cpu.s !== 8'hfd || db_device.memory.data[16'h01fe] !== 8'h34)
                        $error("TEST FAILED: PHP, s=%h, mem[01fe]=%h", db_device.cpu.s, db_device.memory.data[16'h01fe]); 
                end
                18: begin
                    // check PLP
                    if (db_device.cpu.s !== 8'hfe || db_device.cpu.flags !== 8'h34)
                        $error("TEST FAILED: PLP, s=%h, flags=%h", db_device.cpu.s, db_device.cpu.flags); 
                end
                22: begin
                    // check PLA
                    if (db_device.cpu.s !== 8'hff || db_device.cpu.a !== 8'h01)
                        $error("TEST FAILED: PLA, s=%h, a=%h", db_device.cpu.s, db_device.cpu.a); 
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
