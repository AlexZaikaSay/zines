// Display chain: video_timing_gen -> nes_scaler -> frame_buffer -> osd_overlay -> video_out,
// wired like a board top. Checks on whole frames:
//   * raster: 800 clocks per line, 525 lines, hsync 96 clocks, vsync 2 lines
//   * picture: display pixel (64 + 2x + i, 2y + j) shows frame buffer pixel (x, y),
//     borders and blanking are black
//   * OSD: an opaque cell covers its 16x16 display pixels, transparent cells do not
//   * pause: with no frame buffer writes the display keeps showing the same frame
/* verilator lint_off STMTDLY */
module tb_105_display;
    import display_pkg::*;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    // frame buffer write port (the PPU side)
    logic       fb_we = 1'b0;
    logic [7:0] fb_wx, fb_wy;
    logic [5:0] fb_wdata;

    // OSD CPU port
    logic        text_we = 1'b0, attr_we = 1'b0;
    logic [10:0] osd_waddr;
    logic [7:0]  osd_wdata;

    logic [9:0] raster_h, raster_v;
    logic       raster_de, raster_hs, raster_vs;
    logic [7:0] fb_rx, fb_ry;
    logic [5:0] fb_index;
    logic [9:0] h1, v1, h2, v2;
    logic       image1, hs1, vs1, image2, hs2, vs2;
    logic [5:0] index2;
    logic       hsync_n, vsync_n;
    logic [3:0] red, green, blue;
    logic [9:0] x, y;

    video_timing_gen u_timing (.clk(clk), .rst_n(rst_n), .h(raster_h), .v(raster_v),
        .de(raster_de), .hsync(raster_hs), .vsync(raster_vs));

    nes_scaler u_scaler (.clk(clk), .rst_n(rst_n), .h(raster_h), .v(raster_v),
        .de(raster_de), .hsync(raster_hs), .vsync(raster_vs), .rx(fb_rx), .ry(fb_ry),
        .h_q(h1), .v_q(v1), .image_q(image1), .hsync_q(hs1), .vsync_q(vs1));

    frame_buffer u_fb (.wclk(clk), .we(fb_we), .wx(fb_wx), .wy(fb_wy), .wdata(fb_wdata),
        .rclk(clk), .rx(fb_rx), .ry(fb_ry), .rdata(fb_index));

    osd_overlay #(.FONT_FILE("data/font.hex")) u_osd (.clk(clk), .rst_n(rst_n),
        .wclk(clk), .text_we(text_we), .attr_we(attr_we), .waddr(osd_waddr), .wdata(osd_wdata),
        .h(raster_h), .v(raster_v),
        .h1(h1), .v1(v1), .image1(image1), .hsync1(hs1), .vsync1(vs1), .index1(fb_index),
        .h2(h2), .v2(v2), .image2(image2), .hsync2(hs2), .vsync2(vs2), .index2(index2));

    video_out u_out (.clk(clk), .rst_n(rst_n), .h(h2), .v(v2), .image(image2), .index(index2),
        .hsync(hs2), .vsync(vs2), .hsync_n(hsync_n), .vsync_n(vsync_n),
        .red(red), .green(green), .blue(blue), .x(x), .y(y));

    // ---- reference model
    function automatic [5:0] pattern(input [7:0] px, input [7:0] py);
        return 6'((px ^ {py[5:0], py[7:6]}) + 8'd5);
    endfunction

    // OSD cell (col 3, row 2): opaque, glyph code 0 (blank) on background color 1 (blue $02).
    // Every other cell keeps attribute 0: transparent.
    localparam int OSD_COL = 3, OSD_ROW = 2;
    localparam logic [5:0] OSD_BG = 6'h02;

    function automatic [5:0] expected_index(input [7:0] px, input [7:0] py);
        if (px[7:3] == 5'(OSD_COL) && py[7:3] == 5'(OSD_ROW))
            return OSD_BG;
        return pattern(px, py);
    endfunction

    // ---- check one whole frame at the outputs, starting at x = y = 0
    int errors = 0;

    task automatic check_frame;
        int hs_len, line_len;
        for (int ln = 0; ln < V_TOTAL; ln++) begin
            hs_len = 0;
            for (int col = 0; col < H_TOTAL; col++) begin
                @(negedge clk);
                if (x != 10'(col) || y != 10'(ln)) begin
                    $display("raster position %0d,%0d expected %0d,%0d", x, y, col, ln);
                    errors++;
                end
                if (!hsync_n) hs_len++;
                if (vsync_n != !(ln >= V_VIS + V_FRONT && ln < V_VIS + V_FRONT + V_SYNC)) begin
                    if (errors < 20) $display("vsync wrong at %0d,%0d", col, ln);
                    errors++;
                end
                begin
                    logic [11:0] want;
                    if (col >= IMG_LEFT && col < IMG_RIGHT && ln < V_VIS) begin
                        logic [7:0] px, py;
                        px = 8'((col - IMG_LEFT) / 2);
                        py = 8'(ln / 2);
                        want = nes_rgb(expected_index(px, py));
                    end else begin
                        want = 12'h000;
                    end
                    if ({red, green, blue} != want) begin
                        if (errors < 20)
                            $display("pixel %0d,%0d: rgb %03h expected %03h", col, ln, {red, green, blue}, want);
                        errors++;
                    end
                end
            end
            if (hs_len != H_SYNC) begin
                $display("line %0d: hsync %0d clocks, expected %0d", ln, hs_len, H_SYNC);
                errors++;
            end
        end
    endtask

    task automatic wait_frame_start;
        do @(negedge clk); while (!(x == 10'(H_TOTAL - 1) && y == 10'(V_TOTAL - 1)));
    endtask

    initial begin
        // the OSD cell, written before the display starts
        repeat (2) @(negedge clk);
        osd_waddr = 11'({5'(OSD_ROW), 1'b0, 5'(OSD_COL)});
        osd_wdata = 8'h00; text_we = 1'b1;
        @(negedge clk) text_we = 1'b0;
        osd_wdata = 8'h80 | 8'h10;   // opaque, background color 1
        attr_we = 1'b1;
        @(negedge clk) attr_we = 1'b0;

        // fill the frame buffer through its write port
        for (int py = 0; py < 240; py++)
            for (int px = 0; px < 256; px++) begin
                fb_wx = 8'(px); fb_wy = 8'(py); fb_wdata = pattern(8'(px), 8'(py)); fb_we = 1'b1;
                @(negedge clk);
            end
        fb_we = 1'b0;

        rst_n = 1'b1;
        wait_frame_start;
        check_frame;
        // "pause": no writes for a whole frame, the same picture must come out again
        check_frame;

        if (errors != 0)
            $fatal(1, "tb_105_display: %0d errors", errors);
        $display("tb_105_display: 2 frames OK");
        $finish;
    end

    initial begin
        #100_000_000;
        $fatal(1, "Timed out");
    end

    wire unused = &{1'b0, fb_rx, fb_ry};
endmodule
/* verilator lint_on STMTDLY */
