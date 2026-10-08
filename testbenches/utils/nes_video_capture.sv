module nes_video_capture #(
    parameter integer FRAMES = 6,
    parameter BMP_BASE = "nes_frame"
) (
    input logic       clk,
    input logic       rst_n,
    input logic [8:0] scanline,
    input logic [8:0] cycle,
    input logic [7:0] palette_color
);

    localparam integer WIDTH = 256;
    localparam integer HEIGHT = 240;

    logic [23:0] nes_rgb [0:63];
    logic [23:0] frame [0:WIDTH*HEIGHT-1];
    integer frames_done = 0;
    integer px;
    string bmp_name;

    initial begin
        nes_rgb[6'h00]=24'h666666; nes_rgb[6'h01]=24'h002A88; nes_rgb[6'h02]=24'h1412A7; nes_rgb[6'h03]=24'h3B00A4;
        nes_rgb[6'h04]=24'h5C007E; nes_rgb[6'h05]=24'h6E0040; nes_rgb[6'h06]=24'h6C0600; nes_rgb[6'h07]=24'h561D00;
        nes_rgb[6'h08]=24'h333500; nes_rgb[6'h09]=24'h0B4800; nes_rgb[6'h0A]=24'h005200; nes_rgb[6'h0B]=24'h004F08;
        nes_rgb[6'h0C]=24'h00404D; nes_rgb[6'h0D]=24'h000000; nes_rgb[6'h0E]=24'h000000; nes_rgb[6'h0F]=24'h000000;
        nes_rgb[6'h10]=24'hADADAD; nes_rgb[6'h11]=24'h155FD9; nes_rgb[6'h12]=24'h4240FF; nes_rgb[6'h13]=24'h7527FE;
        nes_rgb[6'h14]=24'hA01ACC; nes_rgb[6'h15]=24'hB71E7B; nes_rgb[6'h16]=24'hB53120; nes_rgb[6'h17]=24'h994E00;
        nes_rgb[6'h18]=24'h6B6D00; nes_rgb[6'h19]=24'h388700; nes_rgb[6'h1A]=24'h0D9300; nes_rgb[6'h1B]=24'h008F32;
        nes_rgb[6'h1C]=24'h007C8D; nes_rgb[6'h1D]=24'h000000; nes_rgb[6'h1E]=24'h000000; nes_rgb[6'h1F]=24'h000000;
        nes_rgb[6'h20]=24'hFFFEFF; nes_rgb[6'h21]=24'h64B0FF; nes_rgb[6'h22]=24'h9290FF; nes_rgb[6'h23]=24'hC676FF;
        nes_rgb[6'h24]=24'hF36AFF; nes_rgb[6'h25]=24'hFE6ECC; nes_rgb[6'h26]=24'hFE8170; nes_rgb[6'h27]=24'hEA9E22;
        nes_rgb[6'h28]=24'hBCBE00; nes_rgb[6'h29]=24'h88D800; nes_rgb[6'h2A]=24'h5CE430; nes_rgb[6'h2B]=24'h45E082;
        nes_rgb[6'h2C]=24'h48CDDE; nes_rgb[6'h2D]=24'h4F4F4F; nes_rgb[6'h2E]=24'h000000; nes_rgb[6'h2F]=24'h000000;
        nes_rgb[6'h30]=24'hFFFEFF; nes_rgb[6'h31]=24'hC0DFFF; nes_rgb[6'h32]=24'hD3D2FF; nes_rgb[6'h33]=24'hE8C8FF;
        nes_rgb[6'h34]=24'hFBC2FF; nes_rgb[6'h35]=24'hFEC4EA; nes_rgb[6'h36]=24'hFECCC5; nes_rgb[6'h37]=24'hF7D8A5;
        nes_rgb[6'h38]=24'hE4E594; nes_rgb[6'h39]=24'hCFEF96; nes_rgb[6'h3A]=24'hBDF4AB; nes_rgb[6'h3B]=24'hB3F3CC;
        nes_rgb[6'h3C]=24'hB5EBF2; nes_rgb[6'h3D]=24'hB8B8B8; nes_rgb[6'h3E]=24'h000000; nes_rgb[6'h3F]=24'h000000;

        for (integer i = 0; i < WIDTH * HEIGHT; i = i + 1)
            frame[i] = 24'h000000;
    end

    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (scanline < HEIGHT && cycle >= 1 && cycle <= WIDTH) begin
                px = scanline * WIDTH + cycle - 1;
                if (^palette_color === 1'bx)
                    frame[px] <= 24'h000000;
                else
                    frame[px] <= nes_rgb[palette_color[5:0]];
            end

            if (scanline == HEIGHT && cycle == 0) begin
                frames_done <= frames_done + 1;
                $sformat(bmp_name, "%s_%0d.bmp", BMP_BASE, frames_done + 1);
                write_bmp(bmp_name);
                $display("nes_video_capture: saved %s", bmp_name);
                if (frames_done + 1 == FRAMES)
                    $finish;
            end
        end
    end

    task automatic put32(input integer fd, input [31:0] value);
        begin
            $fwrite(fd, "%c%c%c%c", value[7:0], value[15:8], value[23:16], value[31:24]);
        end
    endtask

    task automatic write_bmp(input string name);
        integer fd, x, y;
        logic [23:0] color;
        begin
            fd = $fopen(name, "wb");
            if (fd == 0)
                $fatal(1, "nes_video_capture: cannot open %s", name);

            $fwrite(fd, "BM");
            put32(fd, 54 + WIDTH * HEIGHT * 3);
            put32(fd, 0);
            put32(fd, 54);
            put32(fd, 40);
            put32(fd, WIDTH);
            put32(fd, HEIGHT);
            $fwrite(fd, "%c%c%c%c", 8'h01, 8'h00, 8'h18, 8'h00);
            put32(fd, 0);
            put32(fd, WIDTH * HEIGHT * 3);
            put32(fd, 2835);
            put32(fd, 2835);
            put32(fd, 0);
            put32(fd, 0);

            for (y = HEIGHT - 1; y >= 0; y = y - 1) begin
                for (x = 0; x < WIDTH; x = x + 1) begin
                    color = frame[y * WIDTH + x];
                    if (^color === 1'bx)
                        color = 24'h000000;
                    $fwrite(fd, "%c%c%c", color[7:0], color[15:8], color[23:16]);
                end
            end
            $fclose(fd);
        end
    endtask

endmodule
