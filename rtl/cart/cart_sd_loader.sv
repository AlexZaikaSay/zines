// Boot loader for the cartridge: reads a raw .nes image from SD sectors starting at
// START_LBA, checks the iNES header and streams it into the cartridge init port.
// Synthesizable counterpart of sim/models/cartridge_loader.sv, same fill_w sequence:
//   FILL_VERTICAL, FILL_PRG_BANKS, FILL_CHR_BANKS once the 16-byte header is checked,
//   then one FILL_PRG_DATA / FILL_CHR_DATA write per byte as it arrives from the card.
// A trainer is skipped. Only what cartridge supports is accepted: mapper 0,
// 16/32 KiB PRG, 0/8 KiB CHR, no four-screen.
//
// Runs on the cartridge clock. Hold the console in reset until loaded goes high.
// error_code is an SD_ERR_* (card) or CART_ERR_* (image) code from zines_pkg.
module cart_sd_loader #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer INIT_SPI_HZ = 400_000,
    parameter integer RUN_SPI_HZ  = 10_000_000,
    parameter logic [31:0] START_LBA = 32'd0,
    // Bytes read from the card: header + PRG + CHR (+ trainer), rounded up to sectors
    parameter integer MAX_FILE_BYTES = 81 * 512
)(
    input  logic        clk,
    input  logic        rst_n,

    // SD card SPI interface
    output logic        sd_clk,
    output logic        sd_cmd,         // MOSI
    input  logic        sd_dat0,        // MISO
    output logic        sd_cs_n,
    input  logic        sd_cd_n,        // card detect, active low

    // cartridge init port
    output logic [2:0]  fill_w,
    output logic [14:0] addr,
    output logic [7:0]  data,

    // Status
    output logic        loaded,
    output logic        error,
    output logic [7:0]  error_code
);
    import zines_pkg::*;

    localparam integer SECTORS = (MAX_FILE_BYTES + 511) / 512;

    // ----------------------------------------------------------------
    // SD stream
    // ----------------------------------------------------------------
    logic        sd_busy, sd_done, sd_error;
    logic [7:0]  sd_error_code;
    logic        byte_valid;
    logic [7:0]  byte_data;
    logic [31:0] byte_index;

    sd_loader #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .INIT_SPI_HZ(INIT_SPI_HZ),
        .RUN_SPI_HZ(RUN_SPI_HZ),
        .LOAD_WORDS(SECTORS * 128),
        .START_LBA(START_LBA)
    ) u_sd_loader (
        .clk(clk),
        .reset_n(rst_n),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd_n),
        .busy(sd_busy),
        .done(sd_done),
        .error(sd_error),
        .error_code(sd_error_code),
        .byte_valid(byte_valid),
        .byte_data(byte_data),
        .byte_index(byte_index)
    );

    // ----------------------------------------------------------------
    // Header (bytes 0-15)
    // ----------------------------------------------------------------
    logic [3:0] magic_ok;
    logic [7:0] prg_banks;          // 16 KiB units
    logic [7:0] chr_banks;          // 8 KiB units
    logic [7:0] flags6;
    logic [7:0] flags7;
    logic       hdr_checked;        // byte 15 seen
    logic [7:0] hdr_error;

    wire [7:0]  mapper      = {flags7[7:4], flags6[7:4]};
    wire        hdr_ok      = hdr_checked && hdr_error == 8'h00;

    wire [31:0] prg_size    = {10'd0, prg_banks, 14'd0};
    wire [31:0] chr_size    = {11'd0, chr_banks, 13'd0};
    wire [31:0] data_start  = flags6[2] ? 32'd16 + 32'd512 : 32'd16;
    wire [31:0] data_off    = byte_index - data_start;
    wire [31:0] chr_off     = data_off - prg_size;
    wire        in_data     = byte_index >= data_start;
    wire        in_prg      = in_data && data_off < prg_size;
    wire        in_chr      = in_data && !in_prg && data_off < prg_size + chr_size;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            magic_ok    <= 4'd0;
            prg_banks   <= 8'd0;
            chr_banks   <= 8'd0;
            flags6      <= 8'd0;
            flags7      <= 8'd0;
            hdr_checked <= 1'b0;
            hdr_error   <= 8'h00;
        end
        else if (byte_valid) begin
            case (byte_index)
                32'd0:  magic_ok[0] <= byte_data == 8'h4E;    // 'N'
                32'd1:  magic_ok[1] <= byte_data == 8'h45;    // 'E'
                32'd2:  magic_ok[2] <= byte_data == 8'h53;    // 'S'
                32'd3:  magic_ok[3] <= byte_data == 8'h1A;
                32'd4:  prg_banks   <= byte_data;
                32'd5:  chr_banks   <= byte_data;
                32'd6:  flags6      <= byte_data;
                32'd7:  flags7      <= byte_data;
                32'd15: begin
                    hdr_checked <= 1'b1;
                    if (magic_ok != 4'hF)
                        hdr_error <= CART_ERR_HEADER;
                    else if (mapper != 8'd0)
                        hdr_error <= CART_ERR_MAPPER;
                    else if (flags6[3])
                        hdr_error <= CART_ERR_FOUR_SCREEN;
                    else if (prg_banks == 8'd0 || prg_banks > 8'd2 || chr_banks > 8'd1)
                        hdr_error <= CART_ERR_SIZE;
                end
                default: ;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Init port writes. The three header writes go out on the clocks after
    // byte 15; the next byte from the card is at least one SPI byte later.
    // ----------------------------------------------------------------
    logic [1:0] hdr_step;           // 0 idle, 1-3 = vertical, prg_banks, chr_banks pending
    logic       hdr_started;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fill_w      <= FILL_NONE;
            addr        <= 15'd0;
            data        <= 8'd0;
            hdr_step    <= 2'd0;
            hdr_started <= 1'b0;
        end
        else begin
            fill_w <= FILL_NONE;

            if (hdr_ok && !hdr_started) begin
                hdr_started <= 1'b1;
                hdr_step    <= 2'd1;
            end

            case (hdr_step)
                2'd1: begin fill_w <= FILL_VERTICAL;  data <= {7'd0, flags6[0]}; hdr_step <= 2'd2; end
                2'd2: begin fill_w <= FILL_PRG_BANKS; data <= prg_banks;         hdr_step <= 2'd3; end
                2'd3: begin fill_w <= FILL_CHR_BANKS; data <= chr_banks;         hdr_step <= 2'd0; end
                default: begin
                    if (byte_valid && hdr_ok && in_prg) begin
                        fill_w <= FILL_PRG_DATA;
                        addr   <= data_off[14:0];
                        data   <= byte_data;
                    end
                    else if (byte_valid && hdr_ok && in_chr) begin
                        fill_w <= FILL_CHR_DATA;
                        addr   <= {2'b00, chr_off[12:0]};
                        data   <= byte_data;
                    end
                end
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Status
    // ----------------------------------------------------------------
    wire hdr_failed = hdr_checked && hdr_error != 8'h00;

    assign loaded     = sd_done && hdr_ok;
    assign error      = sd_error || hdr_failed;
    assign error_code = sd_error ? sd_error_code : hdr_error;

    wire unused = &{1'b0, sd_busy, flags6[1], flags7[3:0], data_off[31:15], chr_off[31:13]};

endmodule
