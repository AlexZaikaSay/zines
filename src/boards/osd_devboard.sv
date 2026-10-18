`include "boards/charmap.sv"
`include "cpu/mos6502.sv"
`include "cpu/mem.sv"
`include "cpu/rom.sv"
`include "ppu/ppu_sim.sv"

module osd_devboard 
#(
    parameter ROM_FILE = "",
    parameter string FONT_FILE = "font.hex"
)
(
    input logic clk,
    input logic rst_n,
    output logic [8:0] scanline,
    output logic [8:0] cycle,
    output logic [7:0] pixel_palette
);

    logic [15:0]    cpu_addr;
    logic [7:0]     cpu_data;
    logic [7:0]     mem_data;
    logic [7:0]     ram_data;
    logic [7:0]     rom_data;
    logic [7:0]     char_code;

    logic [7:0]     osd_pixels;
    logic [7:0]     ppu_pixels;
    
    logic cpu_rw;
    logic undef;

    wire ram_selected           = cpu_addr[15:13] == 3'b000;    // $0000-$1FFF
    wire rom_selected           = cpu_addr[15];                 // $8000-$FFFF

    mos6502 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_addr),
        .data_out(cpu_data),
        .data_in(mem_data),
        .rw(cpu_rw),
        .nmi_n(1),
        .irq_n(1),
        .undef(undef)
    );

    assign mem_data = ram_selected ? ram_data :
                      rom_selected ? rom_data :
                      8'h00;

    ppu_sim ppu (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_color(ppu_pixels),
        .scanline(scanline),
        .cycle(cycle)
    );

    charmap #(
        .FONT_FILE(FONT_FILE)
    ) charmap_inst (
        .clk(clk),
        .char_code(char_code[6:0]),
        .row(scanline[2:0]),
        .col(cycle[2:0]),
        .pixels(osd_pixels)
    );

    localparam MEMIO_OSD_TEXT = 16'h2000;
    localparam MEMIO_OSD_ATTR = 16'h2800;

    localparam PPU_WIDTH = 256;
    localparam PPU_HEIGHT = 240;

    wire [5:0] osd_x = cycle[8:3];
    wire [5:0] osd_y = scanline[8:3];
    wire osd_visible_char = cycle < PPU_WIDTH && scanline < PPU_HEIGHT;
    wire [10:0] osd_pos = (osd_y << 6) + osd_x;

    wire osd_text_selected = (cpu_addr[15:0] >= MEMIO_OSD_TEXT) && (cpu_addr[15:0] < MEMIO_OSD_ATTR);
    // CPU writes to $2000-$27FF go to the text buffer; otherwise the display reads it
    wire osd_text_write = osd_text_selected && !cpu_rw;
    wire [10:0] osd_text_addr = osd_text_write ? cpu_addr[10:0] : osd_pos;

    assign pixel_palette = (osd_pixels != 0) && osd_visible_char ? osd_pixels : ppu_pixels;

    // text frame buffer
    mem #(
        .ADDR_WIDTH(11)
    ) osd_text_mem (
        .clk(clk),
        .addr(osd_text_addr),
        .data_in(cpu_data),
        .rw(!osd_text_write),
        .cs_n(0),
        .oe_n(0),
        .data_out(char_code)
    );

    // Async read: mos6502 samples data in the same cycle it drives addr
    mem #(
        .ADDR_WIDTH(13)
    ) ram (
        .clk(clk),
        .addr(cpu_addr[12:0]),
        .data_in(cpu_data),
        .rw(cpu_rw),
        .cs_n(!ram_selected),
        .oe_n(!cpu_rw),
        .data_out(ram_data)
    );

    rom #(
        .ADDR_WIDTH(15),
        .ROM_FILE(ROM_FILE)
    ) rom (
        .addr(cpu_addr),
        .data_out(rom_data),
        .re(rom_selected && cpu_rw)
    );

endmodule
