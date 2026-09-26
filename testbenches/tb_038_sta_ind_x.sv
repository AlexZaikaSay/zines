
`include "devboard.sv"

/* verilator lint_off STMTDLY */



module tb_038_sta_ind_x;
    parameter CYCLE_LEN = 10;
    parameter MEM_FILE = "./tests/038_sta_ind_x.tv";
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
        $dumpfile("tb_038_sta_ind_x.vcd");
        $dumpvars(0, tb_038_sta_ind_x);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 20; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (i)
                10: begin
                    // check STA (ind,x)
                    if (db_device.memory.data[16'h0202] !== 8'h15)
                        $error("TEST FAILED: STA (IND,X)"); 
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
