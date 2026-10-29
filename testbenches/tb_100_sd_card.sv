`include "cpu/mem.sv"
`include "sd_card/disk.sv"
`include "sd_card/sim_sd_card.sv"

// disk + sim_sd_card through the CPU registers: command before init fails,
// init, read a sector, write a sector, read it back, check the image file.
module tb_100_sd_card;
    localparam string  SD_FILE = "tb_100_sd.img";
    localparam integer SECTORS = 8;

    localparam logic [7:0] SD_BUSY  = 8'h01;
    localparam logic [7:0] SD_ERROR = 8'h02;
    localparam logic [7:0] SD_READY = 8'h04;
    localparam logic [7:0] SD_SDHC  = 8'h08;

    localparam logic [7:0] SD_CMD_INIT  = 8'h01;
    localparam logic [7:0] SD_CMD_READ  = 8'h02;
    localparam logic [7:0] SD_CMD_WRITE = 8'h03;

    localparam logic [7:0] E_NOT_INIT = 8'h02;

    logic       clk = 1'b0;
    logic       rst_n = 1'b0;
    logic       reg_sel = 1'b0;
    logic       buf_sel = 1'b0;
    logic [8:0] addr = '0;
    logic       rw = 1'b1;
    logic [7:0] data_in = '0;
    logic [7:0] data_out;

    logic sd_clk, sd_mosi, sd_miso, sd_cs_n;

    // Sector buffer, shared like on the board
    logic [7:0] reg_data, buf_data;
    logic       buf_active, buf_we;
    logic [8:0] buf_addr;
    logic [7:0] buf_wdata;

    assign data_out = buf_sel ? buf_data : reg_data;

    mem #(
        .ADDR_WIDTH(9)
    ) sector_buf (
        .clk,
        .addr(buf_active ? buf_addr : addr),
        .data_in(buf_active ? buf_wdata : data_in),
        .rw(!(buf_active ? buf_we : (buf_sel && !rw))),
        .cs_n(1'b0),
        .oe_n(1'b0),
        .data_out(buf_data)
    );

    always #5 clk = ~clk;

    disk #(
        .CLK_FREQ_HZ(8_000_000),
        .INIT_SPI_HZ(400_000),
        .RUN_SPI_HZ(1_000_000)
    ) dut (
        .clk, .rst_n,
        .reg_sel, .reg_addr(addr[2:0]), .rw, .data_in, .data_out(reg_data),
        .buf_active, .buf_addr, .buf_we, .buf_wdata, .buf_rdata(buf_data),
        .sd_clk, .sd_cmd(sd_mosi), .sd_dat0(sd_miso), .sd_cs_n,
        .sd_cd_n(1'b0)
    );

    sim_sd_card #(
        .SD_FILE(SD_FILE)
    ) card (
        .clk, .rst_n,
        .sd_clk, .sd_cmd(sd_mosi), .sd_cs_n, .sd_dat0(sd_miso)
    );

    function automatic logic [7:0] pattern(input integer sector, input integer i);
        return 8'((sector * 37) ^ i ^ (i >> 8));
    endfunction

    // ---------------- CPU bus ----------------
    task automatic bus_write(input logic regs, input logic [8:0] a, input logic [7:0] d);
        @(negedge clk);
        reg_sel = regs; buf_sel = !regs; addr = a; rw = 1'b0; data_in = d;
        @(negedge clk);
        reg_sel = 1'b0; buf_sel = 1'b0; rw = 1'b1;
    endtask

    task automatic bus_read(input logic regs, input logic [8:0] a, output logic [7:0] d);
        @(negedge clk);
        reg_sel = regs; buf_sel = !regs; addr = a; rw = 1'b1;
        #1 d = data_out;
        @(negedge clk);
        reg_sel = 1'b0; buf_sel = 1'b0;
    endtask

    task automatic command(input logic [7:0] cmd, input logic [31:0] lba,
                           output logic [7:0] status);
        integer timeout;
        bus_write(1, 9'd4, lba[7:0]);
        bus_write(1, 9'd5, lba[15:8]);
        bus_write(1, 9'd6, lba[23:16]);
        bus_write(1, 9'd7, lba[31:24]);
        bus_write(1, 9'd0, cmd);
        timeout = 0;
        do begin
            bus_read(1, 9'd1, status);
            timeout++;
            if (timeout > 1_000_000)
                $fatal(1, "command %0d timed out", cmd);
        end while (status & SD_BUSY);
    endtask

    task automatic check_buffer(input integer sector);
        logic [7:0] d;
        for (int i = 0; i < 512; i++) begin
            bus_read(0, 9'(i), d);
            if (d !== pattern(sector, i))
                $fatal(1, "sector %0d byte %0d: %02h, expected %02h",
                       sector, i, d, pattern(sector, i));
        end
    endtask

    // ---------------- Test ----------------
    integer     fd, n;
    logic [7:0] status, errcode, d;
    logic [7:0] image [0:SECTORS*512-1];

    initial begin
        $dumpfile("tb_100_sd_card.vcd");
        $dumpvars(0, tb_100_sd_card);

        // Test image: every sector filled with its own pattern
        fd = $fopen(SD_FILE, "wb");
        for (int s = 0; s < SECTORS; s++)
            for (int i = 0; i < 512; i++)
                $fwrite(fd, "%c", pattern(s, i));
        $fclose(fd);

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        // Read before init is rejected
        command(SD_CMD_READ, 32'd1, status);
        bus_read(1, 9'd2, errcode);
        if (!(status & SD_ERROR) || errcode != E_NOT_INIT)
            $fatal(1, "read before init: status %02h errcode %02h", status, errcode);

        // Init
        command(SD_CMD_INIT, 32'd0, status);
        bus_read(1, 9'd2, errcode);
        if (status != (SD_READY | SD_SDHC))
            $fatal(1, "init: status %02h errcode %02h", status, errcode);

        // Read sector 3
        command(SD_CMD_READ, 32'd3, status);
        if (status != (SD_READY | SD_SDHC))
            $fatal(1, "read: status %02h", status);
        check_buffer(3);

        // Write sector 5 with sector 6's pattern, read it back
        for (int i = 0; i < 512; i++)
            bus_write(0, 9'(i), pattern(6, i));
        command(SD_CMD_WRITE, 32'd5, status);
        if (status != (SD_READY | SD_SDHC))
            $fatal(1, "write: status %02h", status);

        for (int i = 0; i < 512; i++)
            bus_write(0, 9'(i), 8'h00);
        command(SD_CMD_READ, 32'd5, status);
        check_buffer(6);

        // The write reached the file and left its neighbours alone
        fd = $fopen(SD_FILE, "rb");
        n = $fread(image, fd);
        $fclose(fd);
        for (int s = 0; s < SECTORS; s++)
            for (int i = 0; i < 512; i++)
                if (image[s*512 + i] !== pattern(s == 5 ? 6 : s, i))
                    $fatal(1, "image sector %0d byte %0d: %02h", s, i, image[s*512 + i]);

        $display("SD card disk test passed");
        $finish;
    end

    initial begin
        repeat (20_000_000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
