create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# PLL outputs: clk[0] ppu_clk, clk[1] vga_clk, clk[2] sd_clk
derive_pll_clocks
derive_clock_uncertainty

# cpu_clk is a register in ppu_clk: high for one PPU clock out of every three
create_generated_clock -name cpu_clk \
    -source [get_pins -compatibility_mode {cpu_clk|clk}] \
    -edges {1 3 7} \
    [get_pins -compatibility_mode {cpu_clk|q}]

# Crossings are handled in RTL: dual-clock RAMs (frame buffer, cartridge), reset
# synchronizers, and cartridge header fields that are static once the console runs.
set_clock_groups -asynchronous \
    -group [get_clocks {*pll1|clk\[0\] cpu_clk}] \
    -group [get_clocks {*pll1|clk\[1\]}] \
    -group [get_clocks {*pll1|clk\[2\]}] \
    -group [get_clocks {CLOCK_50}]

# Push button and card-detect are asynchronous
set_false_path -from [get_ports {RESET_N SD_CD}]
