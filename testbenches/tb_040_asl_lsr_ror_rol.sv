
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_040_asl_lsr_ror_rol;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/040_asl_lsr_ror_rol.tv";
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
        $dumpfile("tb_040_asl_lsr_ror_rol.vcd");
        $dumpvars(0, tb_040_asl_lsr_ror_rol);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 12; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check ASL a
                    if (db_device.cpu.a !== 8'h54 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h1)
                        $error("TEST FAILED: ASL A a=%h z=%b n=%b c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                6: begin
                    // check LSR a
                    if (db_device.cpu.a !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: LSR A a=%h z=%b n=%b c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end            
                8: begin
                    // check ROR a
                    if (db_device.cpu.a !== 8'h15 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROR A a=%h z=%b n=%b c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                10: begin
                    // check ROL a
                    if (db_device.cpu.a !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROL A a=%h z=%b n=%b c=%b", db_device.cpu.a, db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
