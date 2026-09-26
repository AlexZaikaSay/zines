
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_055_alu_ind_y;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/055_alu_ind_y.tv";
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
        $dumpfile("tb_055_alu_ind_y.vcd");
        $dumpvars(0, tb_055_alu_ind_y);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 90; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                11: begin
                    // check ADC (ind),y (55 + 55)
                    if (db_device.cpu.a !== 8'haa || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: ADC (ind),y, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                18: begin
                    // check ADC (ind),y (01 + FF) 
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: ADC (ind),y, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                25: begin
                    // check SBC (ind),y (81 - 02)
                    if (db_device.cpu.a !== 8'h7f || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC (ind),y, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                32: begin
                    // check SBC (ind),y (02 - 01)
                    if (db_device.cpu.a !== 8'h01 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC (ind),y, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                39: begin
                    // check AND (ind),y (55 - AA)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: AND (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                46: begin
                     // check AND (ind),y (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: AND (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                53: begin
                    // check ORA (ind),y (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                60: begin
                     // check ORA (ind),y (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                67: begin
                    // check EOR (ind),y (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: EOR (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                74: begin
                     // check EOR (ind),y (55 - 55)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: EOR (ind),y, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
