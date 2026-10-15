// One Cyclone 10 LP PLL from the 50 MHz board clock. VCO = 50 MHz * 145 / 9 = 805.56 MHz:
//   c0 ppu_clk = VCO / 150 =  5.3704 MHz  (NTSC NES 5.3693 MHz, +0.02%)
//   c1 vga_clk = VCO /  32 = 25.1736 MHz  (640x480@60 nominal 25.175 MHz)
//   c2 sd_clk  = VCO /  16 = 50.3472 MHz  (SD loader logic; SPI SCK is divided from it)
// The multiply/divide pairs below are each output relative to inclk0.
module nes_pll (
    input  logic inclk,
    output logic ppu_clk,
    output logic vga_clk,
    output logic sd_clk,
    output logic locked
);
    wire [4:0] clk;

    altpll #(
        .bandwidth_type("AUTO"),
        .clk0_divide_by(1350),
        .clk0_duty_cycle(50),
        .clk0_multiply_by(145),
        .clk0_phase_shift("0"),
        .clk1_divide_by(288),
        .clk1_duty_cycle(50),
        .clk1_multiply_by(145),
        .clk1_phase_shift("0"),
        .clk2_divide_by(144),
        .clk2_duty_cycle(50),
        .clk2_multiply_by(145),
        .clk2_phase_shift("0"),
        .compensate_clock("CLK0"),
        .inclk0_input_frequency(20000),     // ps
        .intended_device_family("Cyclone 10 LP"),
        .lpm_type("altpll"),
        .operation_mode("NORMAL"),
        .pll_type("AUTO"),
        .port_activeclock("PORT_UNUSED"),
        .port_areset("PORT_UNUSED"),
        .port_clkbad0("PORT_UNUSED"),
        .port_clkbad1("PORT_UNUSED"),
        .port_clkloss("PORT_UNUSED"),
        .port_clkswitch("PORT_UNUSED"),
        .port_configupdate("PORT_UNUSED"),
        .port_fbin("PORT_UNUSED"),
        .port_inclk0("PORT_USED"),
        .port_inclk1("PORT_UNUSED"),
        .port_locked("PORT_USED"),
        .port_pfdena("PORT_UNUSED"),
        .port_phasecounterselect("PORT_UNUSED"),
        .port_phasedone("PORT_UNUSED"),
        .port_phasestep("PORT_UNUSED"),
        .port_phaseupdown("PORT_UNUSED"),
        .port_pllena("PORT_UNUSED"),
        .port_scanaclr("PORT_UNUSED"),
        .port_scanclk("PORT_UNUSED"),
        .port_scanclkena("PORT_UNUSED"),
        .port_scandata("PORT_UNUSED"),
        .port_scandataout("PORT_UNUSED"),
        .port_scandone("PORT_UNUSED"),
        .port_scanread("PORT_UNUSED"),
        .port_scanwrite("PORT_UNUSED"),
        .port_clk0("PORT_USED"),
        .port_clk1("PORT_USED"),
        .port_clk2("PORT_USED"),
        .port_clk3("PORT_UNUSED"),
        .port_clk4("PORT_UNUSED"),
        .port_clkena0("PORT_UNUSED"),
        .port_clkena1("PORT_UNUSED"),
        .port_clkena2("PORT_UNUSED"),
        .port_clkena3("PORT_UNUSED"),
        .port_clkena4("PORT_UNUSED"),
        .port_clkena5("PORT_UNUSED"),
        .port_extclk0("PORT_UNUSED"),
        .port_extclk1("PORT_UNUSED"),
        .port_extclk2("PORT_UNUSED"),
        .port_extclk3("PORT_UNUSED"),
        .self_reset_on_loss_lock("OFF"),
        .width_clock(5)
    ) u_altpll (
        .inclk({1'b0, inclk}),
        .clk(clk),
        .locked(locked)
    );

    assign ppu_clk = clk[0];
    assign vga_clk = clk[1];
    assign sd_clk  = clk[2];

endmodule
