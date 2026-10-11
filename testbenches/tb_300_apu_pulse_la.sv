
`include "boards/rp_devboard.sv"

/* verilator lint_off STMTDLY */



module tb_300_apu_pulse_la;
    parameter CYCLE_LEN = 10;
    parameter CPU_CLK_DIV = 12;
    parameter MEM_FILE = "./tests/300_apu_pulse_la.tv";
    logic clk;
    logic cpu_clk;
    logic [4:0] phase;
    logic rst_n;


    always_ff @(posedge clk) begin
        phase   <= (phase == CPU_CLK_DIV - 1) ? 0 : phase + 1;
        cpu_clk <= (phase < CPU_CLK_DIV / 2);
    end

    rp_devboard #(
        .MEM_FILE(MEM_FILE)
    )
    db_device
    (
        .clk(clk),
        .cpu_clk(cpu_clk),
        .rst_n(rst_n)
    );

    initial begin
        $dumpfile("tb_300_apu_pulse_la.vcd");
        $dumpvars(0, tb_300_apu_pulse_la);
        #1 rst_n = 0; #2; rst_n = 1;
    end

    initial begin
        for (integer i = 0, counter = 0; counter < 600000; i++) begin
            counter = i / CPU_CLK_DIV;
            clk = 1; #(CYCLE_LEN/2);
            clk = 0; #(CYCLE_LEN/2);
            case (counter)
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
