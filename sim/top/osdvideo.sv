`timescale 1ns/1ps

module osdvideo (
    input logic clk
);
 
    parameter ROM_FILE = "./data/osd.tv";
    parameter string FONT_FILE = "./data/font.hex";
    parameter string SD_FILE = "./data/sd.img";

    logic [9:0] disp_h;
    logic [9:0] disp_v;
    logic       disp_image;
    logic [5:0] disp_index;
    logic [7:0] pad_buttons;

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
        .pad_buttons(pad_buttons),
        .disp_h(disp_h),
        .disp_v(disp_v),
        .disp_image(disp_image),
        .disp_index(disp_index)
    );

    // initial begin
    //     $dumpfile("osdvideo.vcd");
    //     $dumpvars(0, osdvideo);
    // end

    import "DPI-C" function void sdl_display_init(input string title);
    import "DPI-C" function void sdl_display_pixel(input int x, input int y, input int palette_index);
    import "DPI-C" function int  sdl_display_present();
    import "DPI-C" function void sdl_display_close();
    import "DPI-C" function int sdl_display_buttons();

    initial sdl_display_init("test OSD");

    // The window shows the NES picture 256x240: one display pixel of each 2x2 block.
    // A frame ends at the first line below the visible 480.
    wire [9:0] pic_x     = disp_h - 10'd64;
    wire       pic_pixel = disp_image && !pic_x[0] && !disp_v[0];
    wire       frame_end = disp_v == 10'd480 && disp_h == 10'd0;

    always @(posedge clk)
        if (frame_end) begin
            pad_buttons <= 8'(sdl_display_buttons());
        end

     // Gamepad simulation, W,S,A,D = Up, Down, Left, Right, right arrow = A, down arrow = B, Enter = Start
    always @(posedge clk or negedge rst_n) begin
        if (rst_n === 1'b1) begin
            if (pic_pixel)
                sdl_display_pixel(int'(pic_x[8:1]), int'(disp_v[8:1]),
                                  (^disp_index === 1'bx) ? 0 : int'(disp_index));

            if (frame_end) begin
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
