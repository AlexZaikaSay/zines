
module cartridge (
    input  logic        clk,            // CPU/PPU port clock

    // CPU side
    input  logic [15:0] cpu_addr,
    output logic [7:0]  cpu_data_out,
    input  logic        cpu_rw,         // 1 = read, 0 = write
    input  logic        cpu_ce_n,       // active low: CPU access to cartridge PRG-ROM
    
    // PPU side
    input  logic [13:0] ppu_addr,
    input  logic        ppu_rd_n,
    input  logic        ppu_wr_n,
    input  logic [7:0]  ppu_data_in,
    output logic [7:0]  ppu_data_out,
    output logic        ciram_a10,
    output logic        ciram_ce_n,     // active low: PPU access to nametable RAM

    // Init side
    input  logic        set_w,          // 1 = write to set registers
    input  logic        prg_w,          // 1 = write to PRG-ROM
    input  logic        chr_w,          // 1 = write to CHR-ROM
    input  logic        vertical,       // mappeer vertical
    input  logic [7:0]  prg_banks,      // 16 KiB PRG
    input  logic [7:0]  chr_banks,      // 8 KiB CHR
    input  logic [7:0]  init_data_in,   // Data to write when rom_w or chrom_w is high
    input  logic [14:0] init_addr       // Address to write when rom_w or chrom_w is high
);


    // ----------------------------------------------------------------
    // Memories (inferred dual-clock block RAM)
    // PRG-ROM and CHR-ROM: loader writes on clk, CPU/PPU read on bus_clk (simple dual port).
    // CHR-RAM (images without CHR data) is a separate single-clock RAM on bus_clk, so no
    // memory is written from both clock domains.
    // ----------------------------------------------------------------
    logic [7:0] prg_mem [0:32767];
    logic [7:0] chr_rom [0:8191];
    logic [7:0] chr_ram [0:8191];

    logic vertical_reg;
    logic [7:0] prg_banks_reg;
    logic [7:0] chr_banks_reg;


    // Loader write ports
    always_ff @(posedge clk) begin
        if (set_w) begin
            vertical_reg <= vertical;
            prg_banks_reg <= prg_banks;
            chr_banks_reg <= chr_banks;
        end
    end

    always_ff @(posedge clk) begin
        if (prg_w)
            prg_mem[init_addr[14:0]] <= init_data_in;
    end

    always_ff @(posedge clk) begin
        if (chr_w)
            chr_rom[init_addr[12:0]] <= init_data_in;
    end

    // ----------------------------------------------------------------
    // NROM CPU side: PRG-ROM at $8000-$FFFF, mirrored when 16 KiB
    // ----------------------------------------------------------------
    wire [14:0] prg_addr    = (prg_banks_reg == 8'd1) ? {1'b0, cpu_addr[13:0]} : cpu_addr[14:0];
    wire        chr_is_ram  = (chr_banks_reg == 8'd0);

    always_ff @(posedge clk) begin
        if (!cpu_ce_n && cpu_rw && cpu_addr[15])
            cpu_data_out <= prg_mem[prg_addr];
    end

    // ----------------------------------------------------------------
    // NROM PPU side: CHR at $0000-$1FFF, nametable mirroring from header
    // ----------------------------------------------------------------
    wire chr_sel = !ppu_addr[13];

    logic [7:0] chr_rom_q;
    logic [7:0] chr_ram_q;

    always_ff @(posedge clk) begin
        if (chr_sel && !ppu_rd_n)
            chr_rom_q <= chr_rom[ppu_addr[12:0]];
    end

    always_ff @(posedge clk) begin
        if (chr_sel && !ppu_wr_n && chr_is_ram)
            chr_ram[ppu_addr[12:0]] <= ppu_data_in;
        if (chr_sel && !ppu_rd_n)
            chr_ram_q <= chr_ram[ppu_addr[12:0]];
    end

    // chr_is_ram is fixed by the header before the console leaves reset
    assign ppu_data_out = chr_is_ram ? chr_ram_q : chr_rom_q;

    // Four-screen is not supported; mirroring follows flags6 bit 0.
    assign ciram_a10 = vertical_reg ? ppu_addr[10] : ppu_addr[11];
    assign ciram_ce_n  = ~ppu_addr[13];

endmodule
