// memio.h — memory map of the menu CPU (6502) <-> Verilog MMIO
// All multi-byte registers are little-endian.
#ifndef MEMIO_H
#define MEMIO_H
#include <stdint.h>
#include "memio_regs.h"   // generated from rtl/common/zines_pkg.sv

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

/* ---------------- Planned, not decoded by the hardware yet ----------------
 * SYS_ID, SYS_STATUS, OSD_CTRL/FG/BG, ST_*, FRAMES*:
 * move each one into zines_pkg (@c-export section) when it is implemented.
 */

/* ---------------- System / NES control ---------------- */
#define SYS_ID        REG8(0x4000)  // R: hardware version
#define NES_CTRL      REG8(OSD_ADDR_NES_CTRL)  // RW
#define   NES_RESET     NES_CTRL_RESET       //   1 = hold NES in reset (set at power-on)
#define   NES_PAUSE     NES_CTRL_PAUSE       //   1 = freeze CPU/PPU/APU clock enable
#define SYS_STATUS    REG8(0x4002)  // R
#define   ST_VBLANK     0x01        //   set at frame start, cleared on read
#define   ST_HOTKEY     0x02        //   long press detected, cleared on read

/* ---------------- Gamepad ---------------- */
#define PAD1          REG8(OSD_ADDR_PAD1)          // R: current buttons
#define PAD1_PRESSED  REG8(OSD_ADDR_PAD1_PRESSED)  // R: nonzero if changed since last PAD1 read
#define   BTN_A       0x01
#define   BTN_B       0x02
#define   BTN_SELECT  0x04
#define   BTN_START   0x08
#define   BTN_UP      0x10
#define   BTN_DOWN    0x20
#define   BTN_LEFT    0x40
#define   BTN_RIGHT   0x80

/* ---------------- OSD ---------------- */
#define OSD_TEXT      MEM8(OSD_ADDR_TEXT)
#define OSD_ATTR      MEM8(OSD_ADDR_ATTR)
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
 *   [6:4] BG color index (colors 0..7 only)
 *   [7]   ATTR_PRESENT: 1 = draw the BG color, 0 = BG transparent
 */
#define ATTR(fg, bg)      ((uint8_t)(((fg) & 0x0F) | (((bg) & 0x07) << 4)))
#define ATTR_FG(fg)       ((uint8_t)((fg) & 0x0F))   /* transparent BG */
 
/* Fixed palette (CGA order) */
enum {
    C_BLACK, C_BLUE, C_GREEN, C_CYAN, C_RED, C_MAGENTA, C_BROWN, C_LGRAY,
    C_DGRAY, C_LBLUE, C_LGREEN, C_LCYAN, C_LRED, C_LMAGENTA, C_YELLOW, C_WHITE
};

#define ATTR_PRESENT 0x80        // attribute bit: opaque BG (see ATTR)

/* ---------------- SD card ----------------
 * Commands SD_CMD_*, status bits SD_BUSY/SD_ERROR/SD_READY/SD_SDHC and
 * error codes SD_ERR_* come from memio_regs.h.
 */
#define SD_BUF        MEM8(OSD_ADDR_SD_BUF)
#define SD_REG(r)     REG8(OSD_ADDR_SD_REGS + (r))
#define SD_CMD        SD_REG(SD_REG_CMD)      // W: start command
#define SD_STATUS     SD_REG(SD_REG_STATUS)   // R
#define SD_ERRCODE    SD_REG(SD_REG_ERRCODE)  // R: error code of the last failed command
#define SD_LBA0       SD_REG(SD_REG_LBA0)     // RW: sector number, 32 bit
#define SD_LBA1       SD_REG(SD_REG_LBA1)
#define SD_LBA2       SD_REG(SD_REG_LBA2)
#define SD_LBA3       SD_REG(SD_REG_LBA3)

/* ---------------- Cartridge loader (NES memories) ----------------
 * Write LD_SEL + LD_ADDR, then stream bytes through LD_DATA.
 * LD_ADDR auto-increments on every LD_DATA access.
 */
#define LD_REG(r)     REG8(OSD_ADDR_LOADER + (r))
#define LD_SEL        LD_REG(LD_REG_SEL)    // RW
#define   LD_PRG_ROM    LD_SEL_PRG_ROM
#define   LD_CHR        LD_SEL_CHR          //   CHR ROM or CHR RAM
#define   LD_PRG_RAM    LD_SEL_PRG_RAM      //   battery RAM ($6000-$7FFF) for .sav
#define LD_ADDR0      LD_REG(LD_REG_ADDR0)  // RW: 24-bit address
#define LD_ADDR1      LD_REG(LD_REG_ADDR1)
#define LD_ADDR2      LD_REG(LD_REG_ADDR2)
#define LD_DATA       LD_REG(LD_REG_DATA)   // W: data port, auto-increment

#define CART_REG(r)   REG8(OSD_ADDR_CART + (r))
#define CART_MAPPER   CART_REG(CART_REG_MAPPER)   // RW
#define CART_FLAGS    CART_REG(CART_REG_FLAGS)    // RW
#define   CART_VERT_MIRROR CART_FLAG_VERTICAL
#define   CART_BATTERY     CART_FLAG_BATTERY
#define   CART_CHR_RAM     CART_FLAG_CHR_RAM
#define CART_PRG_16K  CART_REG(CART_REG_PRG_16K)  // RW: PRG size in 16 KB units
#define CART_CHR_8K   CART_REG(CART_REG_CHR_8K)   // RW: CHR size in 8 KB units (0 = CHR RAM)

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
