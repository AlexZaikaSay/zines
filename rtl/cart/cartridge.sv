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
    output logic [7:0]  sv_data_out     // valid 2 clks after an SV_*_READ, held until the next read
);

    import zines_pkg::*;

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

    wire        chr_sel     = !ppu_addr[13];
    wire [14:0] prg_addr    = (prg_banks == 8'd1) ? {1'b0, cpu_addr[13:0]} : cpu_addr[14:0];
    wire [12:0] chr_addr    = ppu_addr[12:0];
    wire        chr_is_ram  = (chr_banks == 8'd0);
    wire        cpu_read    = !cpu_ce_n && cpu_rw && cpu_addr[15];
    wire        ppu_read    = !ppu_rd_n && chr_sel;
    wire        ppu_wr      = chr_sel && !ppu_wr_n && chr_is_ram;
    
    wire        sv_prg_rd   = (sv_sel == SV_PRG_READ);
    wire        sv_chr_rd   = (sv_sel == SV_CHR_READ);
    wire        sv_chr_wr   = (sv_sel == SV_CHR_WRITE) && chr_is_ram;
    wire [14:0] prg_rd_addr = sv_prg_rd ? sv_addr : prg_addr;
    wire [12:0] chr_rd_addr = sv_chr_rd ? sv_addr[12:0] : chr_addr;

    wire        ch_ram_wr   = sv_chr_wr || ppu_wr;
    wire [12:0] ch_ram_addr = sv_chr_wr ? sv_addr[12:0] : ppu_addr[12:0];
    wire [7:0]  ch_ram_data = sv_chr_wr ? sv_data_in    : ppu_data_in;

    logic [7:0] chr_rom_q;
    logic [7:0] chr_ram_q;
    logic [7:0] prg_q;

    logic [3:0] sv_rd_d;
    
    // ----------------------------------------------------------------
    // NROM CPU side: PRG-ROM at $8000-$FFFF, mirrored when 16 KiB
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        sv_rd_d <= sv_sel;
        if (sv_rd_d == SV_PRG_READ)
            sv_data_out <= prg_q;
        if (sv_rd_d == SV_CHR_READ)
            sv_data_out <= chr_is_ram ? chr_ram_q : chr_rom_q;
    end

    always_ff @(posedge clk) begin
        if (cpu_read || sv_prg_rd)
            prg_q <= prg_mem[prg_rd_addr];
    end

    // ----------------------------------------------------------------
    // NROM PPU side: CHR at $0000-$1FFF, nametable mirroring from header
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (ppu_read || sv_chr_rd)
            chr_rom_q <= chr_rom[chr_rd_addr];
    end

    always_ff @(posedge clk) begin
        if (ch_ram_wr)
            chr_ram[ch_ram_addr] <= ch_ram_data;
        if (ppu_read || sv_chr_rd)
            chr_ram_q <= chr_ram[chr_rd_addr];
    end

    // chr_is_ram is fixed by the header before the console leaves reset
    assign ppu_data_out = chr_is_ram ? chr_ram_q : chr_rom_q;

    // Four-screen is not supported; mirroring follows flags6 bit 0.
    assign ciram_a10 = vertical ? ppu_addr[10] : ppu_addr[11];
    assign ciram_ce_n  = ~ppu_addr[13];

    assign cpu_data_out = prg_q;

endmodule
