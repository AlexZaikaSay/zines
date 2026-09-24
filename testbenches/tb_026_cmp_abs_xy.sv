
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_026_cmp_abs_xy;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/026_cmp_abs_xy.tv";
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
        $dumpfile("tb_026_cmp_abs_xy.vcd");
        $dumpvars(0, tb_026_cmp_abs_xy);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 30; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                8: begin
                    // check CMP abs,x
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CMP ABS, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                15: begin
                    // check CMP abs,x
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CMP ABS, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                21: begin
                    // check CMP abs,y
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CMP ABS, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                28: begin
                    // check CMP abs,y
                    if (db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: CMP ABS, z=%b, n=%b, c=%b", db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
