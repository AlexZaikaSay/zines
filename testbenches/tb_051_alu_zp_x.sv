
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_051_alu_zp_x;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/051_alu_zp_x.tv";
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
        $dumpfile("tb_051_alu_zp_x.vcd");
        $dumpvars(0, tb_051_alu_zp_x);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 70; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                10: begin
                    // check ADC zp,x (55 + 55)
                    if (db_device.cpu.a !== 8'haa || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: ADC ZP, X, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                16: begin
                    // check ADC zp,x (01 + FF) 
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: ADC ZP, X, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                22: begin
                    // check SBC zp,x(81 - 02)
                    if (db_device.cpu.a !== 8'h7f || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC ZP, X, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                28: begin
                    // check SBC zp,x (02 - 01)
                    if (db_device.cpu.a !== 8'h01 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC ZP, X, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                34: begin
                    // check AND zp,x (55 - AA)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: AND ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                40: begin
                     // check AND zp,x (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: AND ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                46: begin
                    // check ORA zp,x (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                52: begin
                     // check ORA zp,x (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                58: begin
                    // check EOR zp,x (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: EOR ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                64: begin
                     // check EOR zp,x (55 - 55)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: EOR ZP, X, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
