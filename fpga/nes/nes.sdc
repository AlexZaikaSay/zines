create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# PLL outputs: clk[0] ppu_clk, clk[1] pix_clk, clk[2] sd_clk, clk[3] tmds_clk (5 x pix_clk)
derive_pll_clocks
derive_clock_uncertainty

# Crossings are handled in RTL: dual-clock RAMs (frame buffer, cartridge), reset
# synchronizers, the audio request/acknowledge handshake, and cartridge header fields
# that are static once the console runs. pix_clk -> tmds_clk (HDMI serializer load)
# is a synchronous, timed crossing, so both stay in one group.
set_clock_groups -asynchronous \
    -group [get_clocks {*pll1|clk\[0\]}] \
    -group [get_clocks {*pll1|clk\[1\] *pll1|clk\[3\]}] \
    -group [get_clocks {*pll1|clk\[2\]}] \
    -group [get_clocks {CLOCK_50}]

# Push button and card-detect are asynchronous
set_false_path -from [get_ports {RESET_N SD_CD}]
