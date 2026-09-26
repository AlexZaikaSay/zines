
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_044_asl_lsr_ror_rol_abs_x;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/044_asl_lsr_ror_rol_abs_x.tv";
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
        $dumpfile("tb_044_asl_lsr_ror_rol_abs_x.vcd");
        $dumpvars(0, tb_044_asl_lsr_ror_rol_abs_x);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 40; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                9: begin
                    // check ASL abs,x
                    if (db_device.memory.data[16'h0202] !== 8'h54 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h1)
                        $error("TEST FAILED: ASL ABS,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                16: begin
                    // check LSR abs,x
                    if (db_device.memory.data[16'h0202] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: LSR ABS,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end            
                23: begin
                    // check ROR abs,x
                    if (db_device.memory.data[16'h0202] !== 8'h15 || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROR ABS,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
                end
                30: begin
                    // check ROL abs,x
                    if (db_device.memory.data[16'h0202] !== 8'h2a || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h0 || db_device.cpu.flags[0] !== 1'h0)
                        $error("TEST FAILED: ROL ABS,X mem=%h z=%b n=%b c=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7], db_device.cpu.flags[0]); 
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
