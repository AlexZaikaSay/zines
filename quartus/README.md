# SD loader Quartus project

This project targets the QMTECH Cyclone 10 Starter Kit V3 with device
`10CL080YU484C8G`.

`top_device` initializes an SD card over SPI, reads the raw image starting at
LBA 0, and displays the fourth byte (`ram[0][31:24]`) as two hexadecimal digits
on the right two 7-segment positions. The left digit is blank. `LEDR` is on
when loading is complete and off while loading or on error.

The clock, reset, LED, 7-segment, and SD-card assignments in `sd_loader.qsf`
use the board mapping:

```text
SD_DAT0 = IO_U19 (SD_D0)
SD_CMD  = IO_W19 (SD_CMD)
SD_CLK  = IO_W20 (SD_CLK)
SD_CS_N = IO_W17 (SD_D3, SPI chip-select)
SD_CD   = IO_T18 (SD_CD)
```

`SD_CD` is active low: low means a card is inserted. If it is high when the
controller starts, loading stops immediately with `error_code = 8'h02`.

Open `sd_loader/sd_loader.qpf` in Quartus, compile, and program the generated `.sof`
file (in `sd_loader/output_files`). The SD card must be connected for the loader to leave its busy state.

`cartridge_demo/cartridge_demo.qpf` loads an iNES file through the `cartridge`
module and shows the first CHR byte on the 7-segment display.

# NES project

`nes/nes.qpf` runs the whole console (`src/nes_sim.sv`) on the board, the FPGA
counterpart of `emulator/tb_200_video.sv`:

- Copy a mapper-0 (NROM) `.nes` file raw to the SD card starting at LBA 0
  (e.g. `dd if=SMB.nes of=/dev/sdX`), insert it, and program `output_files/nes.sof`.
- `LEDR` lights when the ROM is loaded and the console has been released from
  reset; `LED2` lights on a load error (no card, bad header, unsupported mapper).
- Video is 640x480@60. By default it goes to the Pmod VGA (same pins as `vga/`),
  with no audio. Uncomment the `VERILOG_MACRO "VIDEO_HDMI=1"` line in `nes.qsf`
  to build for the board's HDMI connector instead, with 48 kHz audio (the APU
  channels mixed to mono, sent on both channels).
- The 256x240 picture is pixel-doubled to 512x480 and centered.
- Player 1 is a real NES controller: LATCH on M20, CLK on M19, DO on L22
  (the pad runs from the board's 3.3 V; DO polarity is `JOY_DO_ACTIVE_LOW` in nes_top.sv).

`nes_pll` makes four clocks from `CLOCK_50` (VCO 1260 MHz): `ppu_clk` 5.362 MHz,
`pix_clk` 25.2 MHz, `sd_clk` 50.4 MHz and `tmds_clk` 126 MHz (HDMI serializer);
`cpu_clk` is `ppu_clk / 3`.
