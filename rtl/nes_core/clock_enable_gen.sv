// CPU clock enable for the NES core: cpu_ce is high for one clk in three.
// ce = 0 pauses it together with the rest of the console: the phase does not
// advance and cpu_ce stays low, so after the pause the CPU/PPU alignment is unchanged.
module clock_enable_gen #
(
    parameter logic [1:0] RESET_PHASE = 2'd0
)
(
    input  logic clk,
    input  logic rst_n,
    input  logic ce,
    output logic cpu_ce
);

    logic [1:0] phase;
    logic       cpu_ce_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase    <= RESET_PHASE;
            cpu_ce_q <= 1'b0;
        end else if (ce) begin
            phase    <= phase + 2'd1;
            cpu_ce_q <= 1'b0;
            if (phase == 2'd2) begin
                phase    <= 2'd0;
                cpu_ce_q <= 1'b1;
            end
        end
    end

    assign cpu_ce = cpu_ce_q && ce;

endmodule
