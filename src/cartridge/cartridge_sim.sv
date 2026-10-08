// Simulation-only NROM cartridge: same CPU/PPU ports and read timing as `cartridge`,
// but the iNES image is read from ROM_FILE at time 0 instead of from an SD card.
module cartridge_sim #(
    parameter string  ROM_FILE      = "../assets/SMB.nes",
    parameter integer MAX_FILE_BYTES = 40976 + 512
)(
    input  logic        clk,

    // CPU side
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_data_in,
    output logic [7:0]  cpu_data_out,
    input  logic        cpu_rw,       // 1 = read, 0 = write
    input  logic        cpu_ce_n,     // active low: CPU access to cartridge PRG-ROM

    // PPU side
    input  logic [13:0] ppu_addr,
    input  logic        ppu_rd_n,
    input  logic        ppu_wr_n,
    input  logic [7:0]  ppu_data_in,
    output logic [7:0]  ppu_data_out,
    output logic        ciram_a10,
    output logic        ciram_ce_n,     // active low: PPU access to nametable RAM

    // Status
    output logic        loaded,
    output logic        error,
    output logic [7:0]  error_code
);
    logic [7:0] image   [0:MAX_FILE_BYTES-1];
    logic [7:0] prg_mem [0:32767];
    logic [7:0] chr_mem [0:8191];

    logic [7:0] prg_banks;
    logic [7:0] chr_banks;
    logic [7:0] flags6;
    logic [7:0] flags7;

    wire       vertical   = flags6[0];
    wire       chr_is_ram = (chr_banks == 8'd0);

    integer file;
    integer bytes_read;
    integer data_start;
    integer prg_size;
    integer chr_size;
    integer i;

    initial begin
        loaded     = 1'b0;
        error      = 1'b0;
        error_code = 8'h00;
        prg_banks  = 8'd0;
        chr_banks  = 8'd0;
        flags6     = 8'd0;
        flags7     = 8'd0;

        for (i = 0; i < 32768; i = i + 1) prg_mem[i] = 8'h00;
        for (i = 0; i < 8192;  i = i + 1) chr_mem[i] = 8'h00;
        for (i = 0; i < MAX_FILE_BYTES; i = i + 1) image[i] = 8'h00;

        file = $fopen(ROM_FILE, "rb");
        if (file == 0)
            $fatal(1, "cartridge_sim: unable to open %s", ROM_FILE);
        bytes_read = $fread(image, file);
        $fclose(file);

        if (bytes_read < 16 ||
            image[0] != 8'h4E || image[1] != 8'h45 ||
            image[2] != 8'h53 || image[3] != 8'h1A) begin
            error_code = 8'h20;
            error      = 1'b1;
            $fatal(1, "cartridge_sim: %s is not an iNES file", ROM_FILE);
        end

        prg_banks = image[4];
        chr_banks = image[5];
        flags6    = image[6];
        flags7    = image[7];

        if ({flags7[7:4], flags6[7:4]} != 8'd0) begin
            error_code = 8'h21;
            error      = 1'b1;
            $fatal(1, "cartridge_sim: only mapper 0 is supported");
        end
        if (prg_banks == 8'd0 || prg_banks > 8'd2 || chr_banks > 8'd1) begin
            error_code = 8'h22;
            error      = 1'b1;
            $fatal(1, "cartridge_sim: unsupported ROM size");
        end

        data_start = 16 + (flags6[2] ? 512 : 0);
        prg_size   = prg_banks * 16384;
        chr_size   = chr_banks * 8192;

        if (bytes_read < data_start + prg_size + chr_size)
            $fatal(1, "cartridge_sim: %s is truncated", ROM_FILE);

        for (i = 0; i < prg_size; i = i + 1)
            prg_mem[i] = image[data_start + i];
        for (i = 0; i < chr_size; i = i + 1)
            chr_mem[i] = image[data_start + prg_size + i];

        loaded = 1'b1;
    end

    // PRG-ROM at $8000-$FFFF, mirrored when 16 KiB
    wire [14:0] prg_addr = (prg_banks == 8'd1) ? {1'b0, cpu_addr[13:0]} : cpu_addr[14:0];

    always_ff @(posedge clk) begin
        if (!cpu_ce_n && cpu_rw && cpu_addr[15])
            cpu_data_out <= prg_mem[prg_addr];
    end

    wire chr_sel = !ppu_addr[13];

    always_ff @(posedge clk) begin
        if (chr_sel && !ppu_wr_n && chr_is_ram)
            chr_mem[ppu_addr[12:0]] <= ppu_data_in;
        if (chr_sel && !ppu_rd_n)
            ppu_data_out <= chr_mem[ppu_addr[12:0]];
    end

    assign ciram_a10 = vertical ? ppu_addr[10] : ppu_addr[11];
    assign ciram_ce_n  = ~ppu_addr[13];

    wire unused = &{1'b0, cpu_data_in};
endmodule
