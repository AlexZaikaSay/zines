
`include "vga.sv"

/* verilator lint_off STMTDLY */



module tb_103_vga;
    parameter CYCLE_LEN = 10;
    logic clk;
    logic rst;

    vga #(
        .CLK_FREQ_HZ(50_000_000),
        .RUN_VGA_HZ(25_000_000)
    ) device
    (
        .clk(clk),
        .reset(rst),
        .hsync(),
        .vsync(),
        .red(),
        .green(),
        .blue()
    );

    initial begin
        $dumpfile("tb_103_vga.vcd");
        $dumpvars(0, tb_103_vga);
        #1 rst = 0; #2; rst = 1;
    end

    initial begin
        for (integer i = 0; i < 900000; i++) begin
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
        end
    end

    always @(negedge clk)
    begin
        // Check for specific memory write conditions here
    end
  
endmodule

/* verilator lint_on STMTDLY */
