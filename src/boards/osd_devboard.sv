`include "boards/charmap.sv"
`include "cpu/mos6502.sv"
`include "cpu/mem.sv"
`include "cpu/rom.sv"
`include "ppu/ppu_sim.sv"
`include "sd_card/disk.sv"
`include "sd_card/sim_sd_card.sv"

module osd_devboard 
#(
    parameter ROM_FILE = "",
    parameter string FONT_FILE = "font.hex",
    parameter string SD_FILE = "sd.img"
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
    logic [7:0]     cpu_in_data;
    logic [7:0]     ram_data;
    logic [7:0]     rom_data;
    logic [7:0]     char_code;
    logic [7:0]     attr_code;
    logic [7:0]     sd_data;

    logic [7:0]     osd_pixels;
    logic [7:0]     ppu_pixels;
    
    logic cpu_rw;
    logic undef;

    localparam MEMIO_OSD_TEXT = 16'h2000;
    localparam MEMIO_OSD_ATTR = 16'h2800;

    localparam PPU_WIDTH = 256;
    localparam PPU_HEIGHT = 240;

    localparam MEMIO_SD_BUF     = 16'h3000; // $3000-$31FF sector buffer
    localparam MEMIO_SD_REGS    = 16'h4020; // $4020-$4027 SD_CMD..SD_LBA3

    wire ram_selected           = cpu_addr[15:13] == 3'b000;    // $0000-$1FFF
    wire rom_selected           = cpu_addr[15];                 // $8000-$FFFF
    wire sd_buffer_selected     = cpu_addr[15:9] == 7'b0011000; // $3000-$31FF
    wire osd_text_selected      = cpu_addr[15:11] == 5'b00100;  // $2000-$27FF
    wire osd_attr_selected      = cpu_addr[15:11] == 5'b00101;  // $2800-$2FFF
    wire sd_regs_selected       = cpu_addr[15:3] == MEMIO_SD_REGS[15:3]; // $4020-$4027

    mos6502 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_addr),
        .data_out(cpu_data),
        .data_in(cpu_in_data),
        .rw(cpu_rw),
        .nmi_n(1),
        .irq_n(1),
        .undef(undef)
    );

    assign cpu_in_data = ram_selected ? ram_data :
                      rom_selected ? rom_data :
                      (sd_buffer_selected || sd_regs_selected) ? sd_data :
                      8'h00;

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
        .addr(cpu_addr[14:0]),
        .data_out(rom_data),
        .re(rom_selected && cpu_rw)
    );

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
        .attr_code(attr_code),
        .row(scanline[2:0]),
        .col(cycle[2:0]),
        .pixels(osd_pixels)
    );


    wire [5:0] osd_x = cycle[8:3];
    wire [5:0] osd_y = scanline[8:3];
    wire osd_visible_char = cycle < PPU_WIDTH && scanline < PPU_HEIGHT;
    wire [10:0] osd_pos = (osd_y << 6) + osd_x;
    
    // CPU writes to $2000-$27FF go to the text buffer; otherwise the display reads it
    wire osd_text_write = osd_text_selected && !cpu_rw;
    wire [10:0] osd_text_addr = osd_text_write ? cpu_addr[10:0] : osd_pos;

    wire osd_attr_write = osd_attr_selected && !cpu_rw;
    wire [10:0] osd_attr_addr = osd_attr_write ? cpu_addr[10:0] : osd_pos;

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

    // attribute frame buffer
    mem #(
        .ADDR_WIDTH(11)
    ) osd_attr_mem (
        .clk(clk),
        .addr(osd_attr_addr),
        .data_in(cpu_data),
        .rw(!osd_attr_write),
        .cs_n(0),
        .oe_n(0),
        .data_out(attr_code)
    );

    // SD card: disk is the command processor, sim_sd_card stands in for the
    // card on the SPI pins and works on SD_FILE
    logic sd_clk, sd_mosi, sd_miso, sd_cs_n;
    logic [7:0] sd_reg_data;
    logic [7:0] sd_buf_data;
    logic       sd_buf_active;
    logic [8:0] sd_buf_addr;
    logic       sd_buf_we;
    logic [7:0] sd_buf_wdata;

    assign sd_data = sd_buffer_selected ? sd_buf_data : sd_reg_data;

    // Sector buffer: owned by disk while a command runs, by the CPU otherwise
    wire       sd_buf_cpu_write = sd_buffer_selected && !cpu_rw;
    wire [8:0] sd_buf_mem_addr  = sd_buf_active ? sd_buf_addr  : cpu_addr[8:0];
    wire [7:0] sd_buf_mem_wdata = sd_buf_active ? sd_buf_wdata : cpu_data;
    wire       sd_buf_mem_write = sd_buf_active ? sd_buf_we    : sd_buf_cpu_write;

    mem #(
        .ADDR_WIDTH(9)
    ) sd_buf_mem (
        .clk(clk),
        .addr(sd_buf_mem_addr),
        .data_in(sd_buf_mem_wdata),
        .rw(!sd_buf_mem_write),
        .cs_n(1'b0),
        .oe_n(1'b0),
        .data_out(sd_buf_data)
    );

    disk disk_inst (
        .clk(clk),
        .rst_n(rst_n),
        .reg_sel(sd_regs_selected),
        .reg_addr(cpu_addr[2:0]),
        .rw(cpu_rw),
        .data_in(cpu_data),
        .data_out(sd_reg_data),
        .buf_active(sd_buf_active),
        .buf_addr(sd_buf_addr),
        .buf_we(sd_buf_we),
        .buf_wdata(sd_buf_wdata),
        .buf_rdata(sd_buf_data),
        .sd_clk(sd_clk),
        .sd_cmd(sd_mosi),
        .sd_dat0(sd_miso),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(1'b0)
    );

    sim_sd_card #(
        .SD_FILE(SD_FILE)
    ) sd_card_sim (
        .clk(clk),
        .rst_n(rst_n),
        .sd_clk(sd_clk),
        .sd_cmd(sd_mosi),
        .sd_cs_n(sd_cs_n),
        .sd_dat0(sd_miso)
    );

endmodule
