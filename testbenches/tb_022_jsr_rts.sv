
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_022_jsr_rts;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/022_jsr_rts.tv";
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
        $dumpfile("tb_022_jsr_rts.vcd");
        $dumpvars(0, tb_022_jsr_rts);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                10: begin
                    // check JSR 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h07 || db_device.cpu.s !== 8'hfd || 
                        db_device.memory.data[16'h1ff] !== 8'h04 || db_device.memory.data[16'h1fe] !== 8'h05)
                        $error("TEST FAILED: JSR, pc: %h%h, s: %h", db_device.cpu.pc_h, db_device.cpu.pc_l, db_device.cpu.s); 
                end
                18: begin
                    // check RTS 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h06 || db_device.cpu.s !== 8'hff)
                        $error("TEST FAILED: RTS, pc: %h%h, s: %h", db_device.cpu.pc_h, db_device.cpu.pc_l, db_device.cpu.s); 
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
