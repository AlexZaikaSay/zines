// Whole console: the OSD firmware mounts the SD card image, shows the game menu,
// and, driven by scripted pad presses, loads the first game (SMB) and starts the NES.
//   Start on the first folder -> file list; Start on the first file -> load + run.
// Then checks that the game runs: SMB turns rendering on within some frames, and
// neither CPU hits an undefined opcode.
module tb_201_zines_load;
    import zines_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic [7:0] rst_cnt = 8'd0;
    logic       rst_n;
    always @(posedge clk)
        if (rst_cnt != 8'd50) rst_cnt <= rst_cnt + 8'd1;
    assign rst_n = (rst_cnt == 8'd50);

    logic [7:0] pad = 8'h00;
    logic       sd_clk, sd_cmd, sd_dat0, sd_cs_n;
    logic       nes_running, nes_undef, sup_undef;

    zines_system #(
        .OSD_ROM_FILE("data/osd.tv"),
        .FONT_FILE("data/font.hex")
    ) u_sys (
        .clk(clk), .rst_n(rst_n), .sup_clk(clk), .pix_clk(clk), .pix_rst_n(rst_n),
        .pad1_buttons(pad), .pad2_buttons(8'h00),
        .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_dat0(sd_dat0), .sd_cs_n(sd_cs_n), .sd_cd_n(1'b0),
        .disp_h(), .disp_v(), .disp_image(), .disp_index(), .disp_hsync(), .disp_vsync(),
        .cpu_ce(), .audio1(), .audio2(), .audio3(), .audio4(),
        .nes_running(nes_running), .nes_undef(nes_undef), .sup_undef(sup_undef)
    );

    sim_sd_card #(.SD_FILE("data/sd.img")) u_sd_card (
        .clk(clk), .rst_n(rst_n), .sd_clk(sd_clk), .sd_cmd(sd_cmd), .sd_cs_n(sd_cs_n), .sd_dat0(sd_dat0));

    initial begin
        for (int i = 0; i < 2048; i++) begin
            u_sys.u_nes.u_cpu_ram.data[i] = 8'h00;
            u_sys.u_nes.u_ciram.data[i]   = 8'h00;
        end
        for (int i = 0; i < 32; i++)
            u_sys.u_nes.u_ppu.u_ppu_palette.data[i] = 8'h0F;
    end

    // firmware bus events
    wire [15:0] sup_addr = u_sys.u_supervisor.cpu_addr;
    wire        sup_rd   = u_sys.u_supervisor.cpu_rw && u_sys.u_supervisor.cpu_ce;

    // The menu loop polls PAD1_PRESSED and reads PAD1 when the buttons changed
    // Returns half a clk after the edge that completes the read, so a pad
    // change made next cannot race with the CPU or the supervisor sampling it
    task automatic wait_read(input logic [15:0] addr);
        do @(negedge clk); while (!(sup_rd && sup_addr == addr));
        @(negedge clk);
    endtask

    task automatic press(input logic [7:0] buttons);
        wait_read(OSD_ADDR_PAD1_PRESSED);   // the menu is idle, waiting for a button
        pad = buttons;
        wait_read(OSD_ADDR_PAD1);           // taken
        pad = 8'h00;
        wait_read(OSD_ADDR_PAD1);           // release taken
    endtask

    localparam logic [7:0] BTN_START = 8'h08;

    int frames = 0;
    logic rendering = 1'b0;

    always @(posedge clk)
        if (u_sys.u_nes.pix_valid && u_sys.u_nes.pix_x == 8'd255 && u_sys.u_nes.pix_y == 8'd239)
            frames <= frames + 1;

    initial begin
        press(BTN_START);                   // first folder
        $display("tb_201: game folder chosen at %0t", $time);
        wait_read(OSD_ADDR_PAD1_PRESSED);
        pad = BTN_START;                    // first file: load and run
        wait_read(OSD_ADDR_PAD1);
        pad = 8'h00;

        wait (nes_running);
        $display("tb_201: NES started at %0t", $time);
        // The OSD must be hidden before the NES starts: the zines simulation
        // stops the supervisor at that moment
        for (int i = 0; i < 64 * 30; i++)
            if (u_sys.u_osd.text[i] != 8'h20 || u_sys.u_osd.attr[i] != 8'h00)
                $fatal(1, "tb_201: OSD cell %0d not cleared when the NES started (%02h/%02h)",
                       i, u_sys.u_osd.text[i], u_sys.u_osd.attr[i]);

        while (frames < 40) begin
            @(posedge clk);
            if (u_sys.u_nes.u_ppu.ppu_mask[4:3] != 2'b00)
                rendering = 1'b1;
        end
        if (!rendering)
            $fatal(1, "tb_201: the game never turned rendering on");
        $display("tb_201: game running, rendering on, %0d frames", frames);
        $finish;
    end

    always @(posedge clk) begin
        if (sup_undef === 1'b1)
            $fatal(1, "tb_201: supervisor undefined opcode at %04h", sup_addr);
        if (nes_running && nes_undef === 1'b1)
            $fatal(1, "tb_201: NES undefined opcode at %04h", u_sys.u_nes.cpu_addr);
    end

    // progress: firmware PC and NES state every 10M clocks
    longint unsigned clocks = 0;
    always @(posedge clk) begin
        clocks <= clocks + 1;
        if (clocks % 10_000_000 == 0)
            $display("tb_201: %0dM clocks, sup pc area %04h, nes_reset %0b, fill %0d",
                     clocks / 1_000_000, sup_addr, u_sys.nes_reset, u_sys.fill_w);
    end

    initial begin
        #1_000_000_000;              // 100M clocks; loading takes ~20M
        $fatal(1, "tb_201: timed out (running %0b, frames %0d)", nes_running, frames);
    end

endmodule
