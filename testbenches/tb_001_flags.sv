
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_001_flags;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/001_flags.tv";
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
        $dumpfile("tb_001_flags.vcd");
        $dumpvars(0, tb_001_flags);
        #1 rst = 0; #(CYCLE_LEN * 2); rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                4: begin
                    // check D
                    if (db_device.cpu.flags[3] !== 1'b0)
                        $error("TEST FAILED: CLD"); 
                end
                6: begin
                    // check D
                    if (db_device.cpu.flags[3] !== 1'b1)
                        $error("TEST FAILED: SED"); 
                end
                8: begin
                    // check C
                    if (db_device.cpu.flags[0] !== 1'b0)
                        $error("TEST FAILED: CLC"); 
                end
                10: begin
                    // check C
                    if (db_device.cpu.flags[0] !== 1'b1)
                        $error("TEST FAILED: SEC"); 
                end
                12: begin
                    // check I
                    if (db_device.cpu.flags[2] !== 1'b0)
                        $error("TEST FAILED: CLI"); 
                end
                14: begin
                    // check I
                    if (db_device.cpu.flags[2] !== 1'b1)
                        $error("TEST FAILED: SEI"); 
                end
                16: begin
                    // check V
                    if (db_device.cpu.flags[6] !== 1'b0)
                        $error("TEST FAILED: CLV"); 
                end
                default: begin
                    // No specific check for this cycle
                end
            endcase
        end
    end
  
endmodule

/* verilator lint_on STMTDLY */
