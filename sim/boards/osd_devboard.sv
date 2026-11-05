module osd_devboard 
#(
    parameter ROM_FILE = "",
    parameter string FONT_FILE = "font.hex",
    parameter string SD_FILE = "sd.img"
)
(
    input logic clk,
    input logic rst_n,
    input logic  [7:0] pad_buttons,
    // display raster (640x480@60 grid) with the picture and the OSD mixed
    output logic [9:0] disp_h,
    output logic [9:0] disp_v,
    output logic       disp_image,      // disp_index is a picture pixel
    output logic [5:0] disp_index
);

    logic [15:0]    cpu_addr;
    logic [7:0]     cpu_data;
    logic [7:0]     cpu_in_data;
    logic [7:0]     ram_data;
    logic [7:0]     rom_data;
    logic [7:0]     sd_data;

    logic [7:0]     ppu_pixels;
    logic [8:0]     scanline;
    logic [8:0]     cycle;
    
    logic [7:0]     pad_previous;

    logic cpu_rw;
    logic undef;

    import zines_pkg::*;

    wire ram_selected           = cpu_addr[15:13] == OSD_ADDR_RAM[15:13];     // $0000-$1FFF
    wire sd_buffer_selected     = cpu_addr[15:9]  == OSD_ADDR_SD_BUF[15:9];   // $3000-$31FF
    wire osd_text_selected      = cpu_addr[15:11] == OSD_ADDR_TEXT[15:11];    // $2000-$27FF
    wire osd_attr_selected      = cpu_addr[15:11] == OSD_ADDR_ATTR[15:11];    // $2800-$2FFF
    wire btn_selected           = cpu_addr        == OSD_ADDR_PAD1;           // $4008
    wire btn_pressed_selected   = cpu_addr        == OSD_ADDR_PAD1_PRESSED;   // $4009
    wire sd_regs_selected       = cpu_addr[15:3]  == OSD_ADDR_SD_REGS[15:3];  // $4020-$4027
    wire rom_selected           = cpu_addr[15]    == OSD_ADDR_ROM[15];        // $8000-$FFFF

    mos6502 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .ce(1'b1),
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
                      btn_selected ? pad_buttons :
                      btn_pressed_selected ? ((pad_previous == pad_buttons) ? 0 : 1) :
                      (sd_buffer_selected || sd_regs_selected) ? sd_data :
                      8'h00;

    // latch previous pad state on button write
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            pad_previous <= 8'h00;
        else if(btn_selected && cpu_rw)
            pad_previous <= pad_buttons;
    end


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

    // ------ display: the PPU writes the frame buffer, the display side reads it
    //        and puts the OSD text on top; one clock drives both sides here
    wire       pix_valid = scanline < 9'd240 && cycle >= 9'd1 && cycle <= 9'd256;
    wire [8:0] pix_x     = cycle - 9'd1;

    logic [9:0] raster_h, raster_v;
    logic       raster_de, raster_hs, raster_vs;
    logic [7:0] fb_rx, fb_ry;
    logic [5:0] fb_index;
    logic [9:0] img_h, img_v;
    logic       img_image, img_hs, img_vs;

    video_timing_gen u_timing (
        .clk(clk),
        .rst_n(rst_n),
        .h(raster_h),
        .v(raster_v),
        .de(raster_de),
        .hsync(raster_hs),
        .vsync(raster_vs)
    );

    nes_scaler u_scaler (
        .clk(clk),
        .rst_n(rst_n),
        .h(raster_h),
        .v(raster_v),
        .de(raster_de),
        .hsync(raster_hs),
        .vsync(raster_vs),
        .rx(fb_rx),
        .ry(fb_ry),
        .h_q(img_h),
        .v_q(img_v),
        .image_q(img_image),
        .hsync_q(img_hs),
        .vsync_q(img_vs)
    );

    frame_buffer u_frame_buffer (
        .wclk(clk),
        .we(pix_valid),
        .wx(pix_x[7:0]),
        .wy(scanline[7:0]),
        .wdata(ppu_pixels[5:0]),
        .rclk(clk),
        .rx(fb_rx),
        .ry(fb_ry),
        .rdata(fb_index)
    );

    // Text ($2000-$27FF) and attribute ($2800-$2FFF) buffers live in the overlay
    osd_overlay #(
        .FONT_FILE(FONT_FILE)
    ) u_osd (
        .clk(clk),
        .rst_n(rst_n),
        .wclk(clk),
        .text_we(osd_text_selected && !cpu_rw),
        .attr_we(osd_attr_selected && !cpu_rw),
        .waddr(cpu_addr[10:0]),
        .wdata(cpu_data),
        .h(raster_h),
        .v(raster_v),
        .h1(img_h),
        .v1(img_v),
        .image1(img_image),
        .hsync1(img_hs),
        .vsync1(img_vs),
        .index1(fb_index),
        .h2(disp_h),
        .v2(disp_v),
        .image2(disp_image),
        .hsync2(),
        .vsync2(),
        .index2(disp_index)
    );

    wire unused_display = &{1'b0, ppu_pixels[7:6], pix_x[8]};

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
