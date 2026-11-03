

module clock_enable_gen #
(
    parameter logic [1:0] RESET_PHASE = 2'd0
)
(
    input  logic clk,
    input  logic rst_n,
    output logic cpu_ce
);

    logic [1:0] phase;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= RESET_PHASE;
            cpu_ce <= 1'b0;
        end else begin
            phase <= phase + 2'd1;
            cpu_ce <= 1'b0;
            if (phase == 2'd2) begin
                phase <= 2'd0;
                cpu_ce <= 1'b1;
            end
        end
    end

endmodule
