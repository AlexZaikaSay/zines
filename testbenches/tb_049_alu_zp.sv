
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_049_alu_zp;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/049_alu_zp.tv";
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
        $dumpfile("tb_049_alu_zp.vcd");
        $dumpvars(0, tb_049_alu_zp);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 60; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                7: begin
                    // check ADC zp (55 + 55)
                    if (db_device.cpu.a !== 8'haa || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: ADC ZP, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                12: begin
                    // check ADC zp (01 + FF) 
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: ADC ZP, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                17: begin
                    // check SBC zp (81 - 02)
                    if (db_device.cpu.a !== 8'h7f || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC ZP, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                22: begin
                    // check SBC zp (02 - 01)
                    if (db_device.cpu.a !== 8'h01 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC ZP, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                27: begin
                    // check AND zp (55 - AA)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: AND ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                32: begin
                     // check AND zp (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: AND ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                37: begin
                    // check ORA zp (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                42: begin
                     // check ORA zp (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                47: begin
                    // check EOR zp (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: EOR ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                52: begin
                     // check EOR zp (55 - 55)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: EOR ZP, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
