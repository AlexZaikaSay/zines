/* verilator lint_off STMTDLY */

// cart_sd_loader + cartridge, with SMB.nes written raw to a sim_sd_card image at LBA 0.
// Checks every PRG and CHR byte and the nametable mirroring against the file, then
// loads an image with a patched mapper number and expects CART_ERR_MAPPER.
module tb_104_cart_sd_loader;
    import zines_pkg::*;

    localparam string  ASSET_FILE  = "../assets/SMB.nes";
    localparam integer ASSET_BYTES = 40976;
    localparam string  SD_FILE     = "tb_104_sd.img";
    localparam integer SECTORS     = (ASSET_BYTES + 511) / 512;
    localparam integer PRG_BYTES   = 32768;
    localparam integer CHR_BYTES   = 8192;
    localparam integer PRG_START   = 16;
    localparam integer CHR_START   = PRG_START + PRG_BYTES;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic sd_clk, sd_mosi, sd_miso, sd_cs_n;

    logic [2:0]  fill_w;
    logic [14:0] init_addr;
    logic [7:0]  init_data;
    logic        loaded, error;
    logic [7:0]  error_code;

    logic [15:0] cpu_addr = 16'h0000;
    logic        cpu_ce_n = 1'b1;
    logic [7:0]  cpu_data_out;
    logic [13:0] ppu_addr = 14'h0000;
    logic        ppu_rd_n = 1'b1;
    logic [7:0]  ppu_data_out;
    logic        ciram_a10, ciram_ce_n;

    cart_sd_loader #(
        .CLK_FREQ_HZ(8_000_000),
        .INIT_SPI_HZ(400_000),
        .RUN_SPI_HZ(2_000_000),
        .MAX_FILE_BYTES(SECTORS * 512)
    ) dut (
        .clk, .rst_n,
        .sd_clk, .sd_cmd(sd_mosi), .sd_dat0(sd_miso), .sd_cs_n,
        .sd_cd_n(1'b0),
        .fill_w, .addr(init_addr), .data(init_data),
        .loaded, .error, .error_code
    );

    sim_sd_card #(
        .SD_FILE(SD_FILE)
    ) card (
        .clk, .rst_n,
        .sd_clk, .sd_cmd(sd_mosi), .sd_cs_n, .sd_dat0(sd_miso)
    );

    cartridge u_cartridge (
        .clk(clk),
        .cpu_addr(cpu_addr),
        .cpu_data_out(cpu_data_out),
        .cpu_rw(1'b1),
        .cpu_ce_n(cpu_ce_n),
        .ppu_addr(ppu_addr),
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(1'b1),
        .ppu_data_in(8'h00),
        .ppu_data_out(ppu_data_out),
        .ciram_a10(ciram_a10),
        .ciram_ce_n(ciram_ce_n),
        .fill_w(fill_w),
        .init_data_in(init_data),
        .init_addr(init_addr)
    );

    logic [7:0] image [0:SECTORS*512-1];
    integer     fd, n;

    task automatic write_card();
        fd = $fopen(SD_FILE, "wb");
        if (fd == 0)
            $fatal(1, "Unable to create %s", SD_FILE);
        for (int i = 0; i < SECTORS*512; i++)
            $fwrite(fd, "%c", image[i]);
        $fclose(fd);
    endtask

    task automatic run_loader();
        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        wait (loaded || error);
        @(posedge clk);
    endtask

    task automatic check_prg(input logic [15:0] a, input integer file_offset);
        cpu_addr = a;
        cpu_ce_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (cpu_data_out !== image[file_offset])
            $fatal(1, "PRG[%04h] expected %02h, got %02h", a, image[file_offset], cpu_data_out);
        cpu_ce_n = 1'b1;
    endtask

    task automatic check_chr(input logic [13:0] a, input integer file_offset);
        ppu_addr = a;
        ppu_rd_n = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        if (ppu_data_out !== image[file_offset])
            $fatal(1, "CHR[%04h] expected %02h, got %02h", a, image[file_offset], ppu_data_out);
        ppu_rd_n = 1'b1;
    endtask

    initial begin
        for (int i = 0; i < SECTORS*512; i++)
            image[i] = 8'h00;
        fd = $fopen(ASSET_FILE, "rb");
        if (fd == 0)
            $fatal(1, "Unable to open %s", ASSET_FILE);
        n = $fread(image, fd);
        $fclose(fd);
        if (n != ASSET_BYTES)
            $fatal(1, "Expected %0d asset bytes, read %0d", ASSET_BYTES, n);

        // ---- Good image ----
        write_card();
        run_loader();
        if (error)
            $fatal(1, "Loader error %02h", error_code);

        for (int i = 0; i < PRG_BYTES; i++)
            check_prg(16'h8000 + 16'(i), PRG_START + i);
        for (int i = 0; i < CHR_BYTES; i++)
            check_chr(14'(i), CHR_START + i);

        // Mirroring from flags6 bit 0: vertical -> PPU A10, horizontal -> PPU A11
        for (int nt = 0; nt < 4; nt++) begin
            ppu_addr = 14'h2000 + 14'(nt * 14'h400);
            #1;
            if (ciram_ce_n !== 1'b0 ||
                ciram_a10 !== (image[6][0] ? ppu_addr[10] : ppu_addr[11]))
                $fatal(1, "Nametable %0d: ciram_ce_n %0b, ciram_a10 %0b", nt, ciram_ce_n, ciram_a10);
        end

        // ---- Mapper 1 in the header: rejected, loaded stays low ----
        image[6][7:4] = 4'd1;
        write_card();
        run_loader();
        if (loaded || error_code !== CART_ERR_MAPPER)
            $fatal(1, "Mapper 1 image: loaded %0b, error_code %02h (expected %02h)",
                   loaded, error_code, CART_ERR_MAPPER);

        $display("%s cart_sd_loader test passed: %0d PRG + %0d CHR bytes, mapper check",
                 ASSET_FILE, PRG_BYTES, CHR_BYTES);
        $finish;
    end

    initial begin
        repeat (50_000_000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
