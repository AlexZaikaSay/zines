// iNES cartridge: loads a .nes image from raw SD sectors (starting at START_LBA),
// parses the header and fills PRG-ROM / CHR memory. Only mapper 0 (NROM) is supported.
// Memory reads are synchronous: data is valid one CLOCK_50 cycle after the address.
module cartridge #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer RUN_SPI_HZ  = 10_000_000,
    parameter logic [31:0] START_LBA = 32'd0,
    // Upper bound of bytes read from the card (16-byte header + PRG + CHR), rounded up to sectors.
    parameter integer MAX_FILE_BYTES = 81 * 512
)(
    input  logic        clk,
    input  logic        reset,

    output logic        sd_clk,
    output logic        sd_cmd,
    input  logic        sd_dat0,
    output logic        sd_cs_n,
    input  logic        sd_cd,

    // CPU side
    input  logic [15:0] cpu_addr,
    input  logic [7:0]  cpu_data_in,
    output logic [7:0]  cpu_data_out,
    input  logic        cpu_rw,       // 1 = read, 0 = write
    input  logic        cpu_ce,

    // PPU side
    input  logic [13:0] ppu_addr,
    input  logic        ppu_rd,
    input  logic        ppu_wr,
    input  logic [7:0]  ppu_data_in,
    output logic [7:0]  ppu_data_out,
    output logic        ciram_a10,
    output logic        ciram_ce,     // active high: PPU access to nametable RAM

    // Status
    output logic        loaded,
    output logic        error,
    output logic [7:0]  error_code
);
    localparam integer SECTORS   = (MAX_FILE_BYTES + 511) / 512;
    localparam integer LOAD_WORDS = SECTORS * 128;

    localparam logic [7:0] ERR_MAGIC  = 8'h20;
    localparam logic [7:0] ERR_MAPPER = 8'h21;
    localparam logic [7:0] ERR_SIZE   = 8'h22;

    // ----------------------------------------------------------------
    // SD streaming
    // ----------------------------------------------------------------
    logic        sd_busy, sd_done, sd_error;
    logic [7:0]  sd_error_code;
    logic        byte_valid;
    logic [7:0]  byte_data;
    logic [31:0] byte_index;

    sd_card #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .RUN_SPI_HZ(RUN_SPI_HZ),
        .LOAD_WORDS(LOAD_WORDS),
        .START_LBA(START_LBA)
    ) sd_card_inst (
        .clk(clk),
        .reset_n(reset),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd),
        .busy(sd_busy),
        .done(sd_done),
        .error(sd_error),
        .error_code(sd_error_code),
        .byte_valid,
        .byte_data,
        .byte_index
    );

    // ----------------------------------------------------------------
    // Header
    // ----------------------------------------------------------------
    logic [3:0] magic_ok;
    logic [7:0] prg_banks;   // 16 KiB units
    logic [7:0] chr_banks;   // 8 KiB units
    logic [7:0] flags6;
    logic [7:0] flags7;
    logic [7:0] hdr_error;

    wire [7:0] mapper      = {flags7[7:4], flags6[7:4]};
    wire       vertical    = flags6[0];
    wire       has_trainer = flags6[2];
    wire       chr_is_ram  = (chr_banks == 8'd0);

    wire [31:0] prg_size   = {10'd0, prg_banks, 14'd0};
    wire [31:0] chr_size   = {11'd0, chr_banks, 13'd0};
    wire [31:0] data_start = 32'd16 + (has_trainer ? 32'd512 : 32'd0);
    wire [31:0] data_off   = byte_index - data_start;

    wire in_prg = (byte_index >= data_start) && (data_off < prg_size);
    wire in_chr = (byte_index >= data_start) && (data_off >= prg_size) &&
                  (data_off < prg_size + chr_size);

    wire hdr_ok = (hdr_error == 8'h00);

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            magic_ok  <= 4'd0;
            prg_banks <= 8'd0;
            chr_banks <= 8'd0;
            flags6    <= 8'd0;
            flags7    <= 8'd0;
            hdr_error <= 8'd0;
        end
        else if (byte_valid) begin
            case (byte_index)
                32'd0:  magic_ok[0] <= (byte_data == 8'h4E);
                32'd1:  magic_ok[1] <= (byte_data == 8'h45);
                32'd2:  magic_ok[2] <= (byte_data == 8'h53);
                32'd3:  magic_ok[3] <= (byte_data == 8'h1A);
                32'd4:  prg_banks   <= byte_data;
                32'd5:  chr_banks   <= byte_data;
                32'd6:  flags6      <= byte_data;
                32'd7:  flags7      <= byte_data;
                32'd15: begin
                    if (magic_ok != 4'hF)
                        hdr_error <= ERR_MAGIC;
                    else if (mapper != 8'd0)
                        hdr_error <= ERR_MAPPER;
                    else if (prg_banks == 8'd0 || prg_banks > 8'd2 || chr_banks > 8'd1)
                        hdr_error <= ERR_SIZE;
                end
                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Memories (inferred block RAM)
    // ----------------------------------------------------------------
    logic [7:0] prg_mem [0:32767];
    logic [7:0] chr_mem [0:8191];

    // Loader write port
    always_ff @(posedge clk) begin
        if (byte_valid && hdr_ok && (byte_index >= 32'd16)) begin
            if (in_prg)
                prg_mem[data_off[14:0]] <= byte_data;
            else if (in_chr)
                chr_mem[(data_off - prg_size) & 32'h1FFF] <= byte_data;
        end
    end

    // ----------------------------------------------------------------
    // Status
    // ----------------------------------------------------------------
    assign loaded     = sd_done && hdr_ok;
    assign error      = sd_error || !hdr_ok;
    assign error_code = sd_error ? sd_error_code : hdr_error;

    // ----------------------------------------------------------------
    // NROM CPU side: PRG-ROM at $8000-$FFFF, mirrored when 16 KiB
    // ----------------------------------------------------------------
    wire [14:0] prg_addr = (prg_banks == 8'd1) ? {1'b0, cpu_addr[13:0]} : cpu_addr[14:0];

    always_ff @(posedge clk) begin
        if (cpu_ce && cpu_rw && cpu_addr[15])
            cpu_data_out <= prg_mem[prg_addr];
    end

    // ----------------------------------------------------------------
    // NROM PPU side: CHR at $0000-$1FFF, nametable mirroring from header
    // ----------------------------------------------------------------
    wire chr_sel = !ppu_addr[13];

    always_ff @(posedge clk) begin
        if (chr_sel && ppu_wr && chr_is_ram)
            chr_mem[ppu_addr[12:0]] <= ppu_data_in;
        if (chr_sel && ppu_rd)
            ppu_data_out <= chr_mem[ppu_addr[12:0]];
    end

    // Four-screen is not supported; mirroring follows flags6 bit 0.
    assign ciram_a10 = vertical ? ppu_addr[10] : ppu_addr[11];
    assign ciram_ce  = ppu_addr[13];

    wire unused = &{1'b0, cpu_data_in, sd_busy};
endmodule
