`define ASSET_FILE "../assets/SMB.nes"

// cartridge loaded from SMB.nes by cartridge_loader; checks PRG,
// CHR and nametable mirroring against the file.
module tb_102_cartridge;
    localparam integer ASSET_BYTES = 40976;
    localparam string  ASSET_FILE = `ASSET_FILE;
    localparam integer PRG_BYTES = 32768;
    localparam integer PRG_START = 16;
    localparam integer CHR_START = PRG_START + PRG_BYTES;

    logic clk = 1'b0;
    logic reset_n = 1'b0;

    logic [15:0] cpu_addr = 16'h0000;
    logic [7:0]  cpu_data_out;
    logic        cpu_ce_n = 1'b1;
    logic [13:0] ppu_addr = 14'h0000;
    logic        ppu_rd_n = 1'b1;
    logic [7:0]  ppu_data_out;
    logic        ciram_a10;
    logic        ciram_ce_n;

    // Loader -> cartridge init port
    logic [2:0]  fill_w;
    logic [14:0] init_addr;
    logic [7:0]  init_data;
    logic        done;
    logic [7:0]  error_code;

    // Expected contents, read independently of the loader
    logic [7:0] image [0:ASSET_BYTES-1];
    integer file;
    integer bytes_read;

    always #5 clk = ~clk;

    cartridge_loader #(
        .ROM_FILE(ASSET_FILE)
    ) loader (
        .clk, .rst_n(reset_n),
        .fill_w,
        .addr(init_addr),
        .data(init_data),
        .done, .error_code
    );

    cartridge dut (
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

    task automatic check_prg(input logic [15:0] addr, input integer file_offset);
        begin
            cpu_addr = addr;
            cpu_ce_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (cpu_data_out !== image[file_offset])
                $fatal(1, "PRG[%04h] expected %02h, got %02h",
                       addr, image[file_offset], cpu_data_out);
            cpu_ce_n = 1'b1;
        end
    endtask

    task automatic check_chr(input logic [13:0] addr, input integer file_offset);
        begin
            ppu_addr = addr;
            ppu_rd_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (ppu_data_out !== image[file_offset])
                $fatal(1, "CHR[%04h] expected %02h, got %02h",
                       addr, image[file_offset], ppu_data_out);
            ppu_rd_n = 1'b1;
        end
    endtask

    // Nametable select: CIRAM is enabled for $2000-$3EFF, A10 follows the
    // header mirroring bit (vertical -> PPU A10, horizontal -> PPU A11).
    task automatic check_ciram(input logic [13:0] addr);
        logic expected_a10;
        begin
            expected_a10 = image[6][0] ? addr[10] : addr[11];
            ppu_addr = addr;
            #1;
            if (ciram_ce_n !== !addr[13])
                $fatal(1, "CIRAM /CE for %04h expected %0b, got %0b", addr, !addr[13], ciram_ce_n);
            if (addr[13] && ciram_a10 !== expected_a10)
                $fatal(1, "CIRAM A10 for %04h expected %0b, got %0b", addr, expected_a10, ciram_a10);
        end
    endtask

    initial begin
        $dumpfile("tb_102_cartridge.vcd");
        $dumpvars(0, tb_102_cartridge);

        file = $fopen(ASSET_FILE, "rb");
        if (file == 0)
            $fatal(1, "Unable to open %s", ASSET_FILE);
        bytes_read = $fread(image, file);
        $fclose(file);
        if (bytes_read != ASSET_BYTES)
            $fatal(1, "Expected %0d bytes, read %0d", ASSET_BYTES, bytes_read);

        repeat (2) @(posedge clk);
        reset_n = 1'b1;
        // A bad file also ends in done, with a nonzero error_code
        wait (done);
        if (error_code != 0)
            $fatal(1, "Loader error %02h", error_code);
        @(posedge clk);

        check_prg(16'h8000, PRG_START);
        check_prg(16'hFFFF, PRG_START + PRG_BYTES - 1);
        check_chr(14'h0000, CHR_START);
        check_chr(14'h1FFF, ASSET_BYTES - 1);
        check_ciram(14'h0400);
        check_ciram(14'h2000);
        check_ciram(14'h2400);
        check_ciram(14'h2800);
        check_ciram(14'h2C00);

        $display("%s cartridge test passed: PRG[8000]=%02h CHR[0000]=%02h",
                 ASSET_FILE, image[PRG_START], image[CHR_START]);
        $finish;
    end

    initial begin
        // Loader writes one byte per clock: 40 KB plus checks
        repeat (100_000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
