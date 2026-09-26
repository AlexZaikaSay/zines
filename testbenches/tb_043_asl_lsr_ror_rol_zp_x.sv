
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_043_asl_lsr_ror_rol_zp_x;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/043_asl_lsr_ror_rol_zp_x.tv";
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
        $dumpfile("tb_043_asl_lsr_ror_rol_zp_x.vcd");
        $dumpvars(0, tb_043_asl_lsr_ror_rol_zp_x);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 30; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                8: begin
                    // check ASL zp,x
                    if (db_device.memory.data[16'h0002] !== 8'h54 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h1)
                        $error("TEST FAILED: ASL ZP,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                14: begin
                    // check LSR zp,x
                    if (db_device.memory.data[16'h0002] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: LSR ZP,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end            
                20: begin
                    // check ROR zp,x
                    if (db_device.memory.data[16'h0002] !== 8'h15 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROR ZP,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                26: begin
                    // check ROL zp,x
                    if (db_device.memory.data[16'h0002] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROL ZP,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
