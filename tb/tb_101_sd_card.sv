// Loads assets/SMB.nes through disk + sim_sd_card sector by sector and
// compares it with the file (zero padding after the end).
module tb_101_sd_card;
    localparam string  ASSET_FILE   = "../assets/SMB.nes";
    localparam integer ASSET_BYTES  = 40976;
    localparam string  SD_FILE      = "tb_101_sd.img";
    localparam integer SECTORS      = (ASSET_BYTES + 511) / 512;

    localparam logic [7:0] SD_BUSY  = 8'h01;
    localparam logic [7:0] SD_ERROR = 8'h02;

    localparam logic [7:0] SD_CMD_INIT = 8'h01;
    localparam logic [7:0] SD_CMD_READ = 8'h02;

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
        .RUN_SPI_HZ(2_000_000)
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

    task automatic bus_write(input logic [8:0] a, input logic [7:0] d);
        @(negedge clk);
        reg_sel = 1'b1; addr = a; rw = 1'b0; data_in = d;
        @(negedge clk);
        reg_sel = 1'b0; rw = 1'b1;
    endtask

    task automatic bus_read(input logic regs, input logic [8:0] a, output logic [7:0] d);
        @(negedge clk);
        reg_sel = regs; buf_sel = !regs; addr = a; rw = 1'b1;
        #1 d = data_out;
        @(negedge clk);
        reg_sel = 1'b0; buf_sel = 1'b0;
    endtask

    task automatic command(input logic [7:0] cmd, input logic [31:0] lba);
        logic [7:0] status, errcode;
        bus_write(9'd4, lba[7:0]);
        bus_write(9'd5, lba[15:8]);
        bus_write(9'd6, lba[23:16]);
        bus_write(9'd7, lba[31:24]);
        bus_write(9'd0, cmd);
        do bus_read(1, 9'd1, status); while (status & SD_BUSY);
        if (status & SD_ERROR) begin
            bus_read(1, 9'd2, errcode);
            $fatal(1, "command %0d lba %0d failed, errcode %02h", cmd, lba, errcode);
        end
    endtask

    integer     fd, n;
    logic [7:0] asset [0:SECTORS*512-1];
    logic [7:0] d, expected;

    initial begin
        $dumpfile("tb_101_sd_card.vcd");
        $dumpvars(0, tb_101_sd_card);

        for (int i = 0; i < SECTORS*512; i++)
            asset[i] = 8'h00;
        fd = $fopen(ASSET_FILE, "rb");
        if (fd == 0)
            $fatal(1, "Unable to open %s", ASSET_FILE);
        n = $fread(asset, fd);
        $fclose(fd);
        if (n != ASSET_BYTES)
            $fatal(1, "Expected %0d asset bytes, read %0d", ASSET_BYTES, n);

        // Card image = asset padded to whole sectors
        fd = $fopen(SD_FILE, "wb");
        for (int i = 0; i < SECTORS*512; i++)
            $fwrite(fd, "%c", asset[i]);
        $fclose(fd);

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        command(SD_CMD_INIT, 0);
        for (int s = 0; s < SECTORS; s++) begin
            command(SD_CMD_READ, s);
            for (int i = 0; i < 512; i++) begin
                bus_read(0, 9'(i), d);
                expected = asset[s*512 + i];
                if (d !== expected)
                    $fatal(1, "Mismatch at byte %0d: %02h, expected %02h",
                           s*512 + i, d, expected);
            end
        end

        $display("%s SD-card load test passed (%0d bytes, %0d sectors)",
                 ASSET_FILE, ASSET_BYTES, SECTORS);
        $finish;
    end

    initial begin
        repeat (50_000_000) @(posedge clk);
        $fatal(1, "Timed out waiting for %s SD-card load", ASSET_FILE);
    end
endmodule
