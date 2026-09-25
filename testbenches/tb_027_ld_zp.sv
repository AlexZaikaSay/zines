
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_027_ld_zp;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/027_ld_zp.tv";
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
        $dumpfile("tb_027_ld_zp.vcd");
        $dumpvars(0, tb_027_ld_zp);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                3: begin
                    // check LDA zp
                    if (db_device.cpu.a !== 8'h0c)
                        $error("TEST FAILED: LDA ZP"); 
                end
                6: begin
                    // check LDX zp
                    if (db_device.cpu.x !== 8'h0c)
                        $error("TEST FAILED: LDX ZP"); 
                end
                9: begin
                    // check LDY zp
                    if (db_device.cpu.y !== 8'h0c)
                        $error("TEST FAILED: LDY ZP"); 
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
