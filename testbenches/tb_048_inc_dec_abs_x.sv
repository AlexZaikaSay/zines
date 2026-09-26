
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_048_inc_dec_abs_x;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/048_inc_dec_abs_x.tv";
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
        $dumpfile("tb_048_inc_dec_abs_x.vcd");
        $dumpvars(0, tb_048_inc_dec_abs_x);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                9: begin
                    // check INC abs,x
                    if (db_device.memory.data[16'h0202] !== 8'hab || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: INC ABS,X mem=%h z=%b n=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7]); 
                end
                16: begin
                    // check DEC abs,x
                    if (db_device.memory.data[16'h0202] !== 8'haa || db_device.cpu.flags[1] !== 1'h0 || db_device.cpu.flags[7] !== 1'h1)
                        $error("TEST FAILED: DEC ABS,X mem=%h z=%b n=%b", db_device.memory.data[16'h0202], db_device.cpu.flags[1], db_device.cpu.flags[7]); 
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
