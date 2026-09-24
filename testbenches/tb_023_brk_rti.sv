
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_023_brk_rti;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/023_brk_rti.tv";
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
        $dumpfile("tb_023_brk_rti.vcd");
        $dumpvars(0, tb_023_brk_rti);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                11: begin
                    // check BRK 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h08 || db_device.cpu.s !== 8'hfc || 
                        db_device.memory.data[16'h1ff] !== 8'h04 || db_device.memory.data[16'h1fe] !== 8'h05 || db_device.memory.data[16'h1fd] !== 8'hb4)
                        $error("TEST FAILED: BRK, pc: %h%h, s: %h", db_device.cpu.pc_h, db_device.cpu.pc_l, db_device.cpu.s); 
                end
                19: begin
                    // check RTI 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h05 || 
                        db_device.cpu.s !== 8'hff || db_device.cpu.flags !== 8'hb4)
                        $error("TEST FAILED: RTI, pc: %h%h, s: %h, flags: %h", db_device.cpu.pc_h, db_device.cpu.pc_l, db_device.cpu.s, db_device.cpu.flags); 
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
