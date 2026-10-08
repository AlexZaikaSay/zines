
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_023_brk_rti;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/023_brk_rti.tv";
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
        $dumpfile("tb_023_brk_rti.vcd");
        $dumpvars(0, tb_023_brk_rti);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 30 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                11: begin
                    // check BRK 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h08 || db_device.cpu.s !== 8'hfc || 
                        db_device.memory.data[16'h1ff] !== 8'h04 || db_device.memory.data[16'h1fe] !== 8'h05 || db_device.memory.data[16'h1fd] !== 8'hf4)
                        $error("TEST FAILED: BRK, pc: %h%h, s: %h", db_device.cpu.pc_h, db_device.cpu.pc_l, db_device.cpu.s); 
                end
                19: begin
                    // check RTI 
                    if (db_device.cpu.pc_h !== 8'h04 || db_device.cpu.pc_l !== 8'h05 || 
                        db_device.cpu.s !== 8'hff || db_device.cpu.flags !== 8'hf4)
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
