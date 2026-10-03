module top_device (
    input  logic       CLOCK_50,
    input  logic       RESET_N,

    // Pmod VGA 1.0 on J11 (red, blue) and J10 (green, sync)
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS
);
    vga #(
        .CLK_FREQ_HZ(50_000_000),
        .RUN_VGA_HZ(25_000_000)
    ) vga_inst (
        .clk(CLOCK_50),
        .reset(RESET_N),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B)
    );
endmodule
