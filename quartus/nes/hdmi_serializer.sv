// 10:1 TMDS serializer: tmds_clk = 5 x pixel clock (same PLL, phase aligned), two
// bits per tmds_clk through DDR output registers, LSB first. The clock lane sends
// 10'b0000011111, one pixel-clock period per symbol.
//
// All I/O banks on the board run at 3.3 V, so the true LVDS-style standards (2.5 V)
// are not available next to other 3.3 V pins. Each TMDS pair is driven as two
// 3.3-V LVTTL outputs instead: the _n pin carries the complement, from its own DDR
// register so both halves switch on the same edge.
module hdmi_serializer (
    input  logic       tmds_clk,
    input  logic [9:0] ch0,         // pixel clock domain, registered
    input  logic [9:0] ch1,
    input  logic [9:0] ch2,
    output logic [2:0] tmds,
    output logic [2:0] tmds_n,
    output logic       tmds_clock,
    output logic       tmds_clock_n
);
    localparam logic [9:0] CLOCK_SYMBOL = 10'b0000011111;

    // Loading once every 5 tmds_clk cycles samples each pixel word exactly once; the
    // pixel/TMDS clock phase relation is fixed by the PLL, so the alignment is stable.
    logic [2:0] phase = 3'd0;
    logic [9:0] shift0 = '0, shift1 = '0, shift2 = '0, shift_clk = '0;

    always_ff @(posedge tmds_clk) begin
        phase <= (phase == 3'd4) ? 3'd0 : phase + 3'd1;
        if (phase == 3'd4) begin
            shift0    <= ch0;
            shift1    <= ch1;
            shift2    <= ch2;
            shift_clk <= CLOCK_SYMBOL;
        end
        else begin
            shift0    <= shift0    >> 2;
            shift1    <= shift1    >> 2;
            shift2    <= shift2    >> 2;
            shift_clk <= shift_clk >> 2;
        end
    end

    wire [3:0] bit_h = {shift_clk[0], shift2[0], shift1[0], shift0[0]};
    wire [3:0] bit_l = {shift_clk[1], shift2[1], shift1[1], shift0[1]};

    // datain_h goes out first (high phase), datain_l second; [7:4] are the _n pins
    altddio_out #(
        .extend_oe_disable("OFF"),
        .intended_device_family("Cyclone 10 LP"),
        .invert_output("OFF"),
        .lpm_hint("UNUSED"),
        .lpm_type("altddio_out"),
        .oe_reg("UNREGISTERED"),
        .power_up_high("OFF"),
        .width(8)
    ) u_ddio (
        .outclock(tmds_clk),
        .datain_h({~bit_h, bit_h}),
        .datain_l({~bit_l, bit_l}),
        .dataout({tmds_clock_n, tmds_n, tmds_clock, tmds}),
        .aclr(1'b0),
        .aset(1'b0),
        .oe(1'b1),
        .outclocken(1'b1),
        .sclr(1'b0),
        .sset(1'b0),
        .oe_out()
    );

endmodule
