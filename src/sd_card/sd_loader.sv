// Boot loader on top of sd_card: after reset, initializes the card and
// streams LOAD_WORDS 32-bit words (LOAD_WORDS / 128 sectors) starting at
// START_LBA, then holds done (or error) high.
module sd_loader #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer INIT_SPI_HZ = 400_000,
    parameter integer RUN_SPI_HZ  = 10_000_000,

    // 16384 words = 64 KiB
    parameter integer LOAD_WORDS  = 16384,

    // First SD sector of the image
    parameter logic [31:0] START_LBA = 32'd0
)(
    input  logic        clk,
    input  logic        reset_n,

    // SD card SPI interface
    output logic        sd_clk,
    output logic        sd_cmd,       // MOSI
    input  logic        sd_dat0,      // MISO
    output logic        sd_cs_n,
    input  logic        sd_cd_n,      // Card detect, active low

    // Status
    output logic        busy,
    output logic        done,
    output logic        error,
    output logic [7:0]  error_code,

    // Streaming output: one-cycle pulse per received data byte
    output logic        byte_valid,
    output logic [7:0]  byte_data,
    output logic [31:0] byte_index
);

    localparam logic [1:0] OP_INIT = 2'd0;
    localparam logic [1:0] OP_READ = 2'd1;

    localparam integer SECTORS = (LOAD_WORDS + 127) / 128;

    logic        req;
    logic [1:0]  op;
    logic        sd_ready, sd_done, sd_error;
    logic        rd_valid;
    logic [8:0]  rd_index;
    logic [31:0] sector;        // sectors loaded so far
    logic        started;

    sd_card #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .INIT_SPI_HZ(INIT_SPI_HZ),
        .RUN_SPI_HZ(RUN_SPI_HZ)
    ) sd_inst (
        .clk(clk),
        .reset_n(reset_n),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd_n),
        .req(req),
        .op(op),
        .lba(START_LBA + sector),
        .ready(sd_ready),
        .done(sd_done),
        .error(sd_error),
        .error_code(error_code),
        .initialized(),
        .sdhc(),
        .rd_valid(rd_valid),
        .rd_index(rd_index),
        .rd_data(byte_data),
        .wr_index(),
        .wr_data(8'hFF)
    );

    assign byte_valid = rd_valid;
    assign byte_index = {sector[22:0], rd_index};

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            req     <= 1'b0;
            op      <= OP_INIT;
            sector  <= 0;
            started <= 1'b0;
            busy    <= 1'b1;
            done    <= 1'b0;
            error   <= 1'b0;
        end
        else begin
            req <= 1'b0;

            if (!started && sd_ready) begin
                started <= 1'b1;
                op      <= OP_INIT;
                req     <= 1'b1;
            end
            else if (sd_error) begin
                busy  <= 1'b0;
                error <= 1'b1;
            end
            else if (sd_done) begin
                // Init finished, or one more sector loaded
                if (op == OP_READ && sector + 1 == SECTORS) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                else begin
                    if (op == OP_READ)
                        sector <= sector + 1'b1;
                    op  <= OP_READ;
                    req <= 1'b1;
                end
            end
        end
    end

endmodule
