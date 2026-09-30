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

Open `sd_loader.qpf` in Quartus, compile, and program the generated `.sof`
file. The SD card must be connected for the loader to leave its busy state.
