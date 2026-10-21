// memio.h — memory map of the menu CPU (6502) <-> Verilog MMIO
// All multi-byte registers are little-endian.
#ifndef MEMIO_H
#define MEMIO_H
#include <stdint.h>

#define REG8(a)  (*(volatile uint8_t *)(a))
#define MEM8(a)  ((volatile uint8_t *)(a))

/* ---------------- Memory map ----------------
 * $0000-$1FFF  RAM 8 KB (zero page, stack, variables)
 * $2000-$27FF  OSD text buffer (row stride 64, up to 64x32 chars)
 * $2800-$2FFF  OSD attributes  (same layout as text)
 * $3000-$31FF  SD sector buffer 512 B
 * $4000-$40FF  I/O registers
 * $8000-$FFFF  ROM 32 KB (vectors at $FFFA)
 */

/* ---------------- System / NES control ---------------- */
#define SYS_ID        REG8(0x4000)  // R: hardware version
#define NES_CTRL      REG8(0x4001)  // RW
#define   NES_RESET     0x01        //   1 = hold NES in reset
#define   NES_PAUSE     0x02        //   1 = freeze CPU/PPU/APU clock enable
#define SYS_STATUS    REG8(0x4002)  // R
#define   ST_VBLANK     0x01        //   set at frame start, cleared on read
#define   ST_HOTKEY     0x02        //   long press detected, cleared on read

/* ---------------- Gamepad ---------------- */
#define PAD1          REG8(0x4008)  // R: current buttons
#define PAD1_PRESSED  REG8(0x4009)  // R: new presses since last read (cleared on read)
#define   BTN_A       0x01
#define   BTN_B       0x02
#define   BTN_SELECT  0x04
#define   BTN_START   0x08
#define   BTN_UP      0x10
#define   BTN_DOWN    0x20
#define   BTN_LEFT    0x40
#define   BTN_RIGHT   0x80

/* ---------------- OSD ---------------- */
#define OSD_TEXT      MEM8(0x2000)
#define OSD_ATTR      MEM8(0x2800)
#define OSD_WIDTH     64
#define OSD_HEIGHT    32
#define OSD_VIS_WIDTH  32
#define OSD_VIS_HEIGHT 30
#define OSD_CTRL      REG8(0x4010)  // RW
#define   OSD_ENABLE    0x01
#define   OSD_DIM_BG    0x02        //   darken game picture under OSD
#define OSD_FG        REG8(0x4011)  // RW: text color index
#define OSD_BG        REG8(0x4012)  // RW: window background color index
#define   ATTR_INVERT   0x01        // attribute bit: inverted cell (cursor)

/* Attribute byte, one per character cell (same layout as OSD_TEXT):
 *   [3:0] FG color index (16-color palette)
 *   [7:4] BG color index (16-color palette)
 */
#define ATTR(fg, bg)      ((uint8_t)(((fg) & 0x0F) | (((bg) & 0x0F) << 4)))
 
/* Fixed palette (CGA order) */
enum {
    C_BLACK, C_BLUE, C_GREEN, C_CYAN, C_RED, C_MAGENTA, C_BROWN, C_LGRAY,
    C_DGRAY, C_LBLUE, C_LGREEN, C_LCYAN, C_LRED, C_LMAGENTA, C_YELLOW, C_WHITE
};

#define ATTR_PRESENT 0x80        // attribute bit: transparent cell

/* ---------------- SD card ---------------- */
#define SD_BUF        MEM8(0x3000)
#define SD_CMD        REG8(0x4020)  // W: start command
#define   SD_CMD_INIT   0x01
#define   SD_CMD_READ   0x02        //   sector SD_LBA -> SD_BUF
#define   SD_CMD_WRITE  0x03        //   SD_BUF -> sector SD_LBA
#define SD_STATUS     REG8(0x4021)  // R
#define   SD_BUSY       0x01
#define   SD_ERROR      0x02
#define   SD_READY      0x04        //   init done
#define   SD_SDHC       0x08        //   block addressing (info only, HW converts)
#define SD_ERRCODE    REG8(0x4022)  // R: error code of the last failed command (sd_card.sv E_*)
#define   SD_ERR_NONE           0x00
#define   SD_ERR_NO_CARD        0x01    //   card detect: no card inserted
#define   SD_ERR_NOT_INIT       0x02    //   read/write before a successful init
#define   SD_ERR_BAD_OP         0x03    //   internal: unknown operation
#define   SD_ERR_R1_TIMEOUT     0x10    //   card did not answer a command
#define   SD_ERR_CMD0           0x11    //   CMD0 (go idle) rejected
#define   SD_ERR_CMD8           0x12    //   CMD8 (interface condition) bad answer
#define   SD_ERR_CMD55          0x13    //   CMD55 (app command) rejected
#define   SD_ERR_ACMD41         0x14    //   ACMD41 (start init) rejected
#define   SD_ERR_ACMD41_TIMEOUT 0x15    //   card stayed in idle state
#define   SD_ERR_CMD58          0x16    //   CMD58 (read OCR) rejected
#define   SD_ERR_CMD16          0x17    //   CMD16 (block size 512) rejected
#define   SD_ERR_READ_R1        0x20    //   CMD17 (read block) rejected
#define   SD_ERR_READ_TOKEN     0x21    //   error token instead of data
#define   SD_ERR_READ_TIMEOUT   0x22    //   no data token in time
#define   SD_ERR_WRITE_R1       0x30    //   CMD24 (write block) rejected
#define   SD_ERR_WRITE_REJECT   0x31    //   data response not "accepted"
#define   SD_ERR_WRITE_TIMEOUT  0x32    //   card busy too long after write
#define SD_LBA0       REG8(0x4024)  // RW: sector number, 32 bit
#define SD_LBA1       REG8(0x4025)
#define SD_LBA2       REG8(0x4026)
#define SD_LBA3       REG8(0x4027)

/* ---------------- Cartridge loader (NES memories) ----------------
 * Write LD_SEL + LD_ADDR, then stream bytes through LD_DATA.
 * LD_ADDR auto-increments on every LD_DATA access.
 */
#define LD_SEL        REG8(0x4030)  // RW
#define   LD_PRG_ROM    0x00
#define   LD_CHR        0x01        //   CHR ROM or CHR RAM
#define   LD_PRG_RAM    0x02        //   battery RAM ($6000-$7FFF) for .sav
#define LD_ADDR0      REG8(0x4031)  // RW: 24-bit address
#define LD_ADDR1      REG8(0x4032)
#define LD_ADDR2      REG8(0x4033)
#define LD_DATA       REG8(0x4034)  // RW: data port, auto-increment

#define CART_MAPPER   REG8(0x4038)  // RW: 0, 1, 2, 4
#define CART_FLAGS    REG8(0x4039)  // RW
#define   CART_VERT_MIRROR 0x01
#define   CART_BATTERY     0x02
#define   CART_CHR_RAM     0x04
#define CART_PRG_16K  REG8(0x403A)  // RW: PRG size in 16 KB units
#define CART_CHR_8K   REG8(0x403B)  // RW: CHR size in 8 KB units (0 = CHR RAM)

/* ---------------- Save state bus ----------------
 * Flat state address space defined in Verilog (CPU regs, PPU regs,
 * APU, mapper regs, WRAM, VRAM, OAM, palette, CHR RAM, PRG RAM).
 * Only valid while NES_PAUSE = 1.
 */
#define ST_ADDR0      REG8(0x4040)  // RW: 16-bit state address
#define ST_ADDR1      REG8(0x4041)
#define ST_DATA       REG8(0x4042)  // RW: data port, auto-increment
#define ST_SIZE0      REG8(0x4044)  // R: total state size in bytes
#define ST_SIZE1      REG8(0x4045)

/* ---------------- Frame counter (play time) ---------------- */
#define FRAMES_LATCH  REG8(0x4050)  // W: latch counter into FRAMES0..3
#define FRAMES0       REG8(0x4051)  // R: frames while NES running, 32 bit
#define FRAMES1       REG8(0x4052)
#define FRAMES2       REG8(0x4053)

#endif // MEMIO_H
