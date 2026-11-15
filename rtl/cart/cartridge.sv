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

    // Supervisor side
    input  logic [3:0]  sv_sel,         // zines_pkg::SV_* code, SV_NONE when idle
    input  logic [7:0]  sv_data_in,     // Value or byte written for the sv_sel code
    input  logic [14:0] sv_addr,        // Byte address for prg_data / chr_data
    output logic [7:0]  sv_data_out     // valid a fixed number of clks after supervisor write
);

    import zines_pkg::*;

    // TODO: temp
    assign sv_data_out = '0;
    // ----------------------------------------------------------------
    // Memories (inferred block RAM, all on clk)
    // PRG-ROM and CHR-ROM: written by the loader through sv_sel, read by the CPU/PPU.
    // CHR-RAM (images without CHR data) is a separate RAM written by the PPU.
    // ----------------------------------------------------------------
    logic [7:0] prg_mem [0:32767];
    logic [7:0] chr_rom [0:8191];
    logic [7:0] chr_ram [0:8191];

    logic vertical;
    logic [7:0] prg_banks;
    logic [7:0] chr_banks;

    // Loader write ports
    always_ff @(posedge clk) begin
        case (sv_sel) 
            SV_VERTICAL:  vertical  <= sv_data_in[0];
            SV_PRG_BANKS: prg_banks <= sv_data_in;
            SV_CHR_BANKS: chr_banks <= sv_data_in;
            SV_PRG_WRITE: prg_mem[sv_addr[14:0]] <= sv_data_in;
            SV_CHR_WRITE: chr_rom[sv_addr[12:0]] <= sv_data_in;
            default: ;
        endcase 
    end

    // ----------------------------------------------------------------
    // NROM CPU side: PRG-ROM at $8000-$FFFF, mirrored when 16 KiB
    // ----------------------------------------------------------------
    wire [14:0] prg_addr    = (prg_banks == 8'd1) ? {1'b0, cpu_addr[13:0]} : cpu_addr[14:0];
    wire        chr_is_ram  = (chr_banks == 8'd0);

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
    assign ciram_a10 = vertical ? ppu_addr[10] : ppu_addr[11];
    assign ciram_ce_n  = ~ppu_addr[13];

endmodule
