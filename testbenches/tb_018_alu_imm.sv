
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_018_alu_imm;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/018_alu_imm.tv";
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
        $dumpfile("tb_018_alu_imm.vcd");
        $dumpvars(0, tb_018_alu_imm);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 48; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                6: begin
                    // check ADC imm (55 + 55)
                    if (db_device.cpu.a !== 8'haa || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: ADC IMM, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                10: begin
                    // check ADC imm (01 + FF) 
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: ADC IMM, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                14: begin
                    // check SBC imm (81 - 02)
                    if (db_device.cpu.a !== 8'h7f || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC IMM, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                18: begin
                    // check SBC imm (02 - 01)
                    if (db_device.cpu.a !== 8'h01 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[6] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0 || db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SBC IMM, a=%h, z=%b, n=%b, v=%b, c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[6], db_device.cpu.flags[0]); 
                end
                22: begin
                    // check AND imm (55 - AA)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: AND IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                26: begin
                     // check AND imm (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: AND IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                30: begin
                    // check ORA imm (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                34: begin
                     // check ORA imm (55 - 55)
                    if (db_device.cpu.a !== 8'h55 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: ORA IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                38: begin
                    // check EOR imm (55 - AA)
                    if (db_device.cpu.a !== 8'hff || db_device.cpu.flags[7] !== 1'b1 || db_device.cpu.flags[1] !== 1'b0)
                        $error("TEST FAILED: EOR IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                42: begin
                     // check EOR imm (55 - 55)
                    if (db_device.cpu.a !== 8'h00 || db_device.cpu.flags[7] !== 1'b0 || db_device.cpu.flags[1] !== 1'b1)
                        $error("TEST FAILED: EOR IMM, a=%h, z=%b, n=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
