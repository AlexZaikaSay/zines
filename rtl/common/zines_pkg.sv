// Constants shared between modules, and between the RTL and the OSD firmware.
//
// Everything between the @c-export markers is turned into osd memio_regs.h by
// tools/gen_memio_regs.py, so the OSD C code and the hardware cannot drift
// apart. In that section use only lines of the form
//     localparam logic [N:0] NAME = W'hXX;    // optional comment
// plus comment lines and blank lines.
/* verilator lint_off UNUSEDPARAM */   // each user needs only some constants
package zines_pkg;

    // @c-export begin

    // ---- OSD CPU memory map ----
    localparam logic [15:0] OSD_ADDR_RAM         = 16'h0000;   // $0000-$1FFF work RAM
    localparam logic [15:0] OSD_ADDR_TEXT        = 16'h2000;   // $2000-$27FF OSD text
    localparam logic [15:0] OSD_ADDR_ATTR        = 16'h2800;   // $2800-$2FFF OSD attributes
    localparam logic [15:0] OSD_ADDR_SD_BUF      = 16'h3000;   // $3000-$31FF SD sector buffer
    localparam logic [15:0] OSD_ADDR_PAD1        = 16'h4008;   // R: current buttons
    localparam logic [15:0] OSD_ADDR_PAD1_PRESSED = 16'h4009;  // R: nonzero if changed since last PAD1 read
    localparam logic [15:0] OSD_ADDR_SD_REGS     = 16'h4020;   // $4020-$4027 disk registers
    localparam logic [15:0] OSD_ADDR_ROM         = 16'h8000;   // $8000-$FFFF firmware ROM

    // ---- Disk registers (offset from OSD_ADDR_SD_REGS) ----
    localparam logic [2:0]  SD_REG_CMD           = 3'd0;       // W: start a command
    localparam logic [2:0]  SD_REG_STATUS        = 3'd1;       // R: SD_BUSY | SD_ERROR | SD_READY | SD_SDHC
    localparam logic [2:0]  SD_REG_ERRCODE       = 3'd2;       // R: SD_ERR_* of the last failed command
    localparam logic [2:0]  SD_REG_LBA0          = 3'd4;       // RW: sector number, little-endian
    localparam logic [2:0]  SD_REG_LBA1          = 3'd5;
    localparam logic [2:0]  SD_REG_LBA2          = 3'd6;
    localparam logic [2:0]  SD_REG_LBA3          = 3'd7;

    // ---- Disk commands (SD_REG_CMD) ----
    localparam logic [7:0]  SD_CMD_INIT          = 8'h01;
    localparam logic [7:0]  SD_CMD_READ          = 8'h02;      // sector SD_LBA -> sector buffer
    localparam logic [7:0]  SD_CMD_WRITE         = 8'h03;      // sector buffer -> sector SD_LBA

    // ---- Disk status bits (SD_REG_STATUS) ----
    localparam logic [7:0]  SD_BUSY              = 8'h01;
    localparam logic [7:0]  SD_ERROR             = 8'h02;
    localparam logic [7:0]  SD_READY             = 8'h04;      // init done
    localparam logic [7:0]  SD_SDHC              = 8'h08;      // block addressing (info only, HW converts)

    // ---- SD error codes (SD_REG_ERRCODE) ----
    localparam logic [7:0]  SD_ERR_NONE          = 8'h00;
    localparam logic [7:0]  SD_ERR_NO_CARD       = 8'h01;      // card detect: no card inserted
    localparam logic [7:0]  SD_ERR_NOT_INIT      = 8'h02;      // read/write before a successful init
    localparam logic [7:0]  SD_ERR_BAD_OP        = 8'h03;      // internal: unknown operation
    localparam logic [7:0]  SD_ERR_R1_TIMEOUT    = 8'h10;      // card did not answer a command
    localparam logic [7:0]  SD_ERR_CMD0          = 8'h11;      // CMD0 (go idle) rejected
    localparam logic [7:0]  SD_ERR_CMD8          = 8'h12;      // CMD8 (interface condition) bad answer
    localparam logic [7:0]  SD_ERR_CMD55         = 8'h13;      // CMD55 (app command) rejected
    localparam logic [7:0]  SD_ERR_ACMD41        = 8'h14;      // ACMD41 (start init) rejected
    localparam logic [7:0]  SD_ERR_ACMD41_TIMEOUT = 8'h15;     // card stayed in idle state
    localparam logic [7:0]  SD_ERR_CMD58         = 8'h16;      // CMD58 (read OCR) rejected
    localparam logic [7:0]  SD_ERR_CMD16         = 8'h17;      // CMD16 (block size 512) rejected
    localparam logic [7:0]  SD_ERR_READ_R1       = 8'h20;      // CMD17 (read block) rejected
    localparam logic [7:0]  SD_ERR_READ_TOKEN    = 8'h21;      // error token instead of data
    localparam logic [7:0]  SD_ERR_READ_TIMEOUT  = 8'h22;      // no data token in time
    localparam logic [7:0]  SD_ERR_WRITE_R1      = 8'h30;      // CMD24 (write block) rejected
    localparam logic [7:0]  SD_ERR_WRITE_REJECT  = 8'h31;      // data response not "accepted"
    localparam logic [7:0]  SD_ERR_WRITE_TIMEOUT = 8'h32;      // card busy too long after write

    // @c-export end

    // ---- disk <-> sd_card operation codes ----
    localparam logic [1:0]  SD_OP_INIT           = 2'd0;
    localparam logic [1:0]  SD_OP_READ           = 2'd1;
    localparam logic [1:0]  SD_OP_WRITE          = 2'd2;

    // ---- Cartridge init port (cartridge.fill_w) ----
    localparam logic [2:0]  FILL_NONE            = 3'd0;
    localparam logic [2:0]  FILL_VERTICAL        = 3'd1;       // init_data_in[0] = vertical mirroring
    localparam logic [2:0]  FILL_PRG_BANKS       = 3'd2;       // init_data_in = PRG size in 16 KiB
    localparam logic [2:0]  FILL_CHR_BANKS       = 3'd3;       // init_data_in = CHR size in 8 KiB (0 = CHR-RAM)
    localparam logic [2:0]  FILL_PRG_DATA        = 3'd4;       // PRG byte at init_addr
    localparam logic [2:0]  FILL_CHR_DATA        = 3'd5;       // CHR byte at init_addr

endpackage
/* verilator lint_on UNUSEDPARAM */
