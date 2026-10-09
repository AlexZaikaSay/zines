`include "cartridge/cartridge_sim.sv"

`define ASSET_FILE "../assets/SMB.nes"

module tb_102_cartridge;
    localparam integer ASSET_BYTES = 40976;
    localparam string  ASSET_FILE = `ASSET_FILE;
    localparam integer PRG_BYTES = 32768;
    localparam integer PRG_START = 16;
    localparam integer CHR_START = PRG_START + PRG_BYTES;

    logic clk = 1'b0;

    logic [15:0] cpu_addr = 16'h0000;
    logic [7:0]  cpu_data_out;
    logic        cpu_ce_n = 1'b1;
    logic [13:0] ppu_addr = 14'h0000;
    logic        ppu_rd_n = 1'b1;
    logic [7:0]  ppu_data_out;
    logic        loaded;
    logic        error;
    logic [7:0]  error_code;

    logic [7:0] asset_image [0:ASSET_BYTES-1];
    integer asset_file;
    integer bytes_read;

    always #5 clk = ~clk;

    cartridge_sim #(
        .ROM_FILE(`ASSET_FILE)
    ) dut (
        .clk,
        .cpu_addr,
        .cpu_data_in(8'h00),
        .cpu_data_out,
        .cpu_rw(1'b1),
        .cpu_ce_n,
        .ppu_addr,
        .ppu_rd_n(ppu_rd_n),
        .ppu_wr_n(1'b1),
        .ppu_data_in(8'h00),
        .ppu_data_out,
        .ciram_a10(),
        .ciram_ce_n(),
        .loaded,
        .error,
        .error_code
    );

    task automatic check_prg(input logic [15:0] addr, input integer file_offset);
        begin
            cpu_addr = addr;
            cpu_ce_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (cpu_data_out !== asset_image[file_offset])
                $fatal(1, "PRG[%04h] expected %02h, got %02h",
                       addr, asset_image[file_offset], cpu_data_out);
            cpu_ce_n = 1'b1;
        end
    endtask

    task automatic check_chr(input logic [13:0] addr, input integer file_offset);
        begin
            ppu_addr = addr;
            ppu_rd_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (ppu_data_out !== asset_image[file_offset])
                $fatal(1, "CHR[%04h] expected %02h, got %02h",
                       addr, asset_image[file_offset], ppu_data_out);
            ppu_rd_n = 1'b1;
        end
    endtask

    initial begin
        $dumpfile("tb_102_cartridge.vcd");
        $dumpvars(0, tb_102_cartridge);
        asset_file = $fopen(ASSET_FILE, "rb");
        if (asset_file == 0)
            $fatal(1, "Unable to open %s", ASSET_FILE);
        bytes_read = $fread(asset_image, asset_file);
        $fclose(asset_file);
        if (bytes_read != ASSET_BYTES)
            $fatal(1, "Expected %0d asset bytes, read %0d", ASSET_BYTES, bytes_read);

        #1;
        if (error)
            $fatal(1, "Cartridge error, code %02h", error_code);
        if (!loaded)
            $fatal(1, "Cartridge not loaded");

        check_prg(16'h8000, PRG_START);
        check_prg(16'hFFFF, PRG_START + PRG_BYTES - 1);
        check_chr(14'h0000, CHR_START);
        check_chr(14'h1FFF, ASSET_BYTES - 1);

        $display("%s cartridge test passed: PRG[8000]=%02h CHR[0000]=%02h",
                 ASSET_FILE, asset_image[PRG_START], asset_image[CHR_START]);
        $finish;
    end

    initial begin
        repeat (1000) @(posedge clk);
        $fatal(1, "Timed out");
    end
endmodule
