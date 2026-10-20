`include "boards/charmap.sv"
`include "cpu/mos6502.sv"
`include "cpu/mem.sv"
`include "cpu/rom.sv"
`include "ppu/ppu_sim.sv"
`include "sd_card/disk.sv"

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
    logic [7:0]     sd_buf_data;

    logic [7:0]     osd_pixels;
    logic [7:0]     ppu_pixels;
    
    logic cpu_rw;
    logic undef;

    logic [7:0]     sd_status;
    logic [7:0]     sd_errcode;
    logic [31:0]    sd_lba;

    localparam MEMIO_OSD_TEXT = 16'h2000;
    localparam MEMIO_OSD_ATTR = 16'h2800;

    localparam PPU_WIDTH = 256;
    localparam PPU_HEIGHT = 240;

    localparam MEMIO_SD_BUF     = 16'h3000;
    localparam MEMIO_SD_CMD     = 16'h4020; // W: start command
    localparam MEMIO_SD_STATUS  = 16'h4021; // R
    localparam MEMIO_SD_ERRCODE = 16'h4022; // R: last R1 / data token on error
    localparam MEMIO_SD_LBA0    = 16'h4024; // RW: sector number, 32 bit
    localparam MEMIO_SD_LBA1    = 16'h4025;
    localparam MEMIO_SD_LBA2    = 16'h4026;
    localparam MEMIO_SD_LBA3    = 16'h4027;

    localparam SD_CMD_INIT      = 8'h01;
    localparam SD_CMD_READ      = 8'h02;    //   sector SD_LBA -> SD_BUF
    localparam SD_CMD_WRITE     = 8'h03;    //   SD_BUF -> sector SD_LBA

    localparam SD_BUSY          = 8'h01;
    localparam SD_ERROR         = 8'h02;
    localparam SD_READY         = 8'h04;    //   init done
    localparam SD_SDHC          = 8'h08;    //   block addressing (info only, HW converts)

    wire ram_selected           = cpu_addr[15:13] == 3'b000;    // $0000-$1FFF
    wire rom_selected           = cpu_addr[15];                 // $8000-$FFFF
    wire sd_buffer_selected     = cpu_addr[15:9] == 7'b0011000; // $3000-$31FF
    wire osd_text_selected      = cpu_addr[15:11] == 5'b00100;  // $2000-$27FF
    wire sd_status_selected     = cpu_addr == MEMIO_SD_STATUS;  // $4021
    wire sd_errcode_selected    = cpu_addr == MEMIO_SD_ERRCODE; // $4022
    wire sd_lba0_selected       = cpu_addr == MEMIO_SD_LBA0;    // $4024
    wire sd_lba1_selected       = cpu_addr == MEMIO_SD_LBA1;    // $4025
    wire sd_lba2_selected       = cpu_addr == MEMIO_SD_LBA2;    // $4026
    wire sd_lba3_selected       = cpu_addr == MEMIO_SD_LBA3;    // $4027

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
                      sd_buffer_selected ? sd_buf_data :
                      sd_status_selected ? sd_status :
                      sd_errcode_selected ? sd_errcode :
                      sd_lba0_selected ? sd_lba[7:0] :
                      sd_lba1_selected ? sd_lba[15:8] :
                      sd_lba2_selected ? sd_lba[23:16] :
                      sd_lba3_selected ? sd_lba[31:24] :
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

    logic sd_active;

    wire sd_buf_cpu_write   = !cpu_rw && cpu_addr == MEMIO_SD_BUF;
    wire sd_buf_cpu_read    =  cpu_rw && cpu_addr == MEMIO_SD_BUF;
    wire sd_cmd_write       = !cpu_rw && cpu_addr == MEMIO_SD_CMD;
    wire sd_status_read     =  cpu_rw && cpu_addr == MEMIO_SD_STATUS;
    wire sd_errcode_read    =  cpu_rw && cpu_addr == MEMIO_SD_ERRCODE;
    wire sd_lba0_write      = !cpu_rw && cpu_addr == MEMIO_SD_LBA0;
    wire sd_lba1_write      = !cpu_rw && cpu_addr == MEMIO_SD_LBA1;
    wire sd_lba2_write      = !cpu_rw && cpu_addr == MEMIO_SD_LBA2;
    wire sd_lba3_write      = !cpu_rw && cpu_addr == MEMIO_SD_LBA3;

    wire [8:0] sd_buf_addr   = sd_active ? sd_addr : cpu_addr[8:0];
    wire sd_buf_in_data = sd_active ? sd_data : cpu_data;


    // sd data buffer
    mem #(
        .ADDR_WIDTH(9)
    ) sd_buf_mem (
        .clk(clk),
        .addr(sd_buf_addr),
        .data_in(sd_buf_in_data),
        .rw(!sd_buf_write),
        .cs_n(0),
        .oe_n(0),
        .data_out(sd_buf_data)
    );

    disk #(
        .SD_FILE(SD_FILE)
    ) disk_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr(sd_addr),
        .rw(cpu_rw),
        .data_in(cpu_data),
        .data_out(sd_data),
        .active(sd_active),
        .status(sd_status),
        .errcode(sd_errcode),
        .lba(sd_lba)
    );


endmodule
