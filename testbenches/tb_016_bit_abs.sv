
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_016_bit_abs;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/016_bit_abs.tv";
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
        $dumpfile("tb_016_bit_abs.vcd");
        $dumpvars(0, tb_016_bit_abs);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 30; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                6: begin
                    // check BIT abs
                    if (db_device.cpu.flags[1] !== 1'h1 || db_device.cpu.flags[7] !== 1'h1 || db_device.cpu.flags[6] !== 1'h1)
                        $error("TEST FAILED: BIT ABS z=%b n=%b v=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6]); 
                end
                12: begin
                    // check BIT abs
                    if (db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1 || db_device.cpu.flags[6] !== 1'h1)
                        $error("TEST FAILED: BIT ABS z=%b n=%b v=%b",  db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6]); 
                end
                18: begin
                    // check BIT abs
                    if (db_device.cpu.flags[1] !== 1'h1 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[6] !== 1'h0)
                        $error("TEST FAILED: BIT ABS z=%b n=%b v=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6]); 
                end
                24: begin
                    // check BIT abs
                    if (db_device.cpu.flags[1] !== 1'h1 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[6] !== 1'h0)
                        $error("TEST FAILED: BIT ABS z=%b n=%b v=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6]); 
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
