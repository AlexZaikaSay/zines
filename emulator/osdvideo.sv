`include "boards/osd_devboard.sv"

`timescale 1ns/1ps

module osdvideo (
    input logic clk
);
 
    parameter ROM_FILE = "./data/osd.tv";
    parameter string FONT_FILE = "./data/font.hex";
    parameter string SD_FILE = "./data/sd.img";

    logic [8:0] scanline;
    logic [8:0] cycle;
    logic [7:0] pixel_palette;

     // clk is driven by utils/sim_main.cpp; reset is held for 50 clocks.
    logic [7:0] rst_cnt = 8'd0;
    always @(posedge clk)
        if (rst_cnt != 8'd50) rst_cnt <= rst_cnt + 8'd1;
    
    assign rst_n = (rst_cnt == 8'd50);

    osd_devboard #
    (
        .ROM_FILE(ROM_FILE),
        .FONT_FILE(FONT_FILE),
        .SD_FILE(SD_FILE)
    )
    u_osd_devboard (
        .clk(clk),
        .rst_n(rst_n),
        .scanline(scanline),
        .cycle(cycle),
        .pixel_palette(pixel_palette)
    );

    initial begin
        $dumpfile("osdvideo.vcd");
        $dumpvars(0, osdvideo);
    end

    import "DPI-C" function void sdl_display_init(input string title);
    import "DPI-C" function void sdl_display_pixel(input int x, input int y, input int palette_index);
    import "DPI-C" function int  sdl_display_present();
    import "DPI-C" function void sdl_display_close();

    initial sdl_display_init("test OSD");


     // Gamepad simulation, W,S,A,D = Up, Down, Left, Right, right arrow = A, down arrow = B, Enter = Start
    always @(posedge clk or negedge rst_n) begin
        if (rst_n === 1'b1) begin
            if (scanline < 240 && cycle >= 1 && cycle <= 256)
                sdl_display_pixel(int'(cycle) - 1, int'(scanline),
                                  (^pixel_palette === 1'bx) ? 0 : int'(pixel_palette[5:0]));

            if (scanline == 240 && cycle == 0) begin
                if (sdl_display_present() != 0) begin
                    sdl_display_close();
                    $finish;
                end
            end
        end
    end

    wire cpu_undef = u_osd_devboard.undef;
    wire [15:0] cpu_addr = u_osd_devboard.cpu_addr;

    always @(posedge clk) begin
        if (cpu_undef === 1'b1)
            $fatal(1, "osdvideo: undefined opcode at %04h", cpu_addr);
    end

endmodule
