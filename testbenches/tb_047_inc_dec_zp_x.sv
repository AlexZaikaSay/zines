
`include "cpu/devboard.sv"

/* verilator lint_off STMTDLY */



module tb_047_inc_dec_zp_x;
    parameter CYCLE_LEN = 10;
    localparam RESET_CYCLES = 7; // reset sequence length before the first fetch
    parameter MEM_FILE = "./tests/047_inc_dec_zp_x.tv";
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
        $dumpfile("tb_047_inc_dec_zp_x.vcd");
        $dumpvars(0, tb_047_inc_dec_zp_x);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0; i < 20 + RESET_CYCLES; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i - RESET_CYCLES)
                8: begin
                    // check INC zp,x
                    if (db_device.memory.data[16'h0002] !== 8'hab || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: INC ZP,X mem=%h z=%b n=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                14: begin
                    // check DEC zp,x
                    if (db_device.memory.data[16'h0002] !== 8'haa || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: DEC ZP,X mem=%h z=%b n=%b", db_device.memory.data[16'h0002], db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
