
module sd_card #(
    // FPGA clock
    parameter integer CLK_FREQ_HZ = 50_000_000,

    // SPI clock during initialization.
    // Must be <= 400 kHz.
    parameter integer INIT_SPI_HZ = 400_000,

    // SPI clock after initialization.
    parameter integer RUN_SPI_HZ  = 10_000_000,

    // Number of 32-bit words to load.
    // 16384 words = 64 KiB.
    parameter integer RAM_WORDS   = 16384,

    // Maximum wait for the data token after CMD17 returns R1.
    parameter integer READ_TOKEN_TIMEOUT_MS = 100,

    // First SD sector containing the binary.
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

    // Loaded RAM
    output logic [RAM_WORDS-1:0][31:0] ram
);

    // ================================================================
    // SPI clock divider
    // ================================================================

    localparam integer INIT_DIV =
        ((CLK_FREQ_HZ + (INIT_SPI_HZ * 2) - 1) /
         (INIT_SPI_HZ * 2));

    localparam integer RUN_DIV =
        ((CLK_FREQ_HZ + (RUN_SPI_HZ * 2) - 1) /
         (RUN_SPI_HZ * 2));

    localparam integer READ_TOKEN_TIMEOUT_CYCLES =
        (CLK_FREQ_HZ / 1000) * READ_TOKEN_TIMEOUT_MS;

    localparam integer MAX_DIV =
        (INIT_DIV > RUN_DIV) ? INIT_DIV : RUN_DIV;

    localparam integer DIV_W =
        (MAX_DIV <= 1) ? 1 : $clog2(MAX_DIV + 1);

    logic             init_mode;

    integer           current_div;

    always_comb begin
        if (init_mode)
            current_div = INIT_DIV;
        else
            current_div = RUN_DIV;

        if (current_div < 1)
            current_div = 1;
    end

    // ================================================================
    // SPI byte engine
    //
    // SPI mode 0:
    //
    //   CPOL = 0
    //   CPHA = 0
    //
    // Data sampled on rising edge.
    // Data changed on falling edge.
    // ================================================================

    logic [7:0] spi_tx;
    logic [7:0] spi_tx_latched;
    logic [7:0] spi_rx;

    logic       spi_start;
    logic       spi_done;

    logic [2:0] spi_bit;
    logic       spi_active;

    logic [DIV_W-1:0] spi_cnt;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sd_clk      <= 1'b0;
            sd_cmd      <= 1'b1;
            spi_tx_latched <= 8'hFF;
            spi_rx      <= 8'h00;

            spi_active  <= 1'b0;
            spi_done    <= 1'b0;
            spi_bit     <= 3'd7;
            spi_cnt     <= '0;
        end
        else begin

            spi_done <= 1'b0;

            // Start a new byte
            if (spi_start && !spi_active) begin
                spi_active <= 1'b1;
                spi_bit    <= 3'd7;
                spi_tx_latched <= spi_tx;
                spi_rx     <= 8'h00;

                sd_clk     <= 1'b0;
                sd_cmd     <= spi_tx[7];
                spi_cnt    <= '0;
            end

            else if (spi_active) begin

                if (spi_cnt >= DIV_W'(current_div - 1)) begin
                    spi_cnt <= '0;

                    // Rising edge
                    if (sd_clk == 1'b0) begin

                        sd_clk <= 1'b1;

                        // Sample MISO
                        spi_rx[spi_bit] <= sd_dat0;

                    end

                    // Falling edge
                    else begin

                        sd_clk <= 1'b0;

                        if (spi_bit == 0) begin

                            spi_active <= 1'b0;
                            spi_done   <= 1'b1;

                            // MOSI idle high
                            sd_cmd <= 1'b1;

                        end
                        else begin

                            spi_bit <= spi_bit - 1'b1;

                            sd_cmd <= spi_tx_latched[spi_bit - 1'b1];

                        end
                    end
                end
                else begin
                    spi_cnt <= spi_cnt + 1'b1;
                end
            end
        end
    end

    // ================================================================
    // Main SD controller
    // ================================================================

    typedef enum logic [5:0] {
        ST_RESET,

        ST_CLOCK_80,

        ST_CMD0_START,
        ST_CMD0_SEND,
        ST_CMD0_WAIT,

        ST_CMD8_START,
        ST_CMD8_SEND,
        ST_CMD8_WAIT,

        ST_ACMD41_CMD55_START,
        ST_ACMD41_CMD55_SEND,
        ST_ACMD41_CMD55_WAIT,
        ST_ACMD41_START,
        ST_ACMD41_SEND,
        ST_ACMD41_WAIT,

        ST_CMD58_START,
        ST_CMD58_SEND,
        ST_CMD58_WAIT,

        ST_CMD16_START,
        ST_CMD16_SEND,
        ST_CMD16_WAIT,

        ST_READ_START,
        ST_READ_SEND,
        ST_READ_WAIT_R1,

        ST_READ_WAIT_TOKEN,
        ST_READ_DATA,

        ST_READ_CRC1,
        ST_READ_CRC2,

        ST_NEXT_SECTOR,

        ST_DONE,
        ST_ERROR
    } state_t;

    state_t state;

    // ================================================================
    // Internal registers
    // ================================================================

    logic [7:0] rx_byte;

    logic [7:0] cmd_buf [0:5];
    logic [2:0] cmd_index;

    logic [7:0] response_count;

    logic [7:0] clock_count;

    logic [31:0] lba;
    logic [31:0] sector_count;
    logic [31:0] byte_address;

    logic [31:0] ram_addr;

    logic [1:0]  word_byte;
    logic [23:0] word_buffer;

    logic [31:0] token_wait_counter;

    // SD type:
    //
    // 1 = SDHC/SDXC
    // 0 = SDSC
    //
    logic sd_high_capacity;

    assign byte_address = lba << 9;


    // CMD58 OCR bytes
    logic [7:0] ocr1;


    // ================================================================
    // SPI helper
    // ================================================================

    always_comb begin
        spi_start = 1'b0;
        spi_tx    = 8'hFF;

        if (!spi_active && !spi_done) begin

            case (state)

                ST_CLOCK_80: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_CMD0_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_CMD0_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_CMD8_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_CMD8_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_ACMD41_CMD55_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_ACMD41_CMD55_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_ACMD41_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_ACMD41_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_CMD58_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_CMD58_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_CMD16_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_CMD16_WAIT: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_READ_SEND: begin
                    spi_start = 1'b1;
                    spi_tx    = cmd_buf[cmd_index];
                end

                ST_READ_WAIT_R1: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_READ_WAIT_TOKEN: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_READ_DATA: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_READ_CRC1: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                ST_READ_CRC2: begin
                    spi_start = 1'b1;
                    spi_tx    = 8'hFF;
                end

                default: begin
                    spi_start = 1'b0;
                    spi_tx    = 8'hFF;
                end

            endcase
        end
    end

    assign rx_byte = spi_rx;

    // ================================================================
    // Main FSM
    // ================================================================

    always_ff @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            state <= ST_RESET;

            sd_cs_n <= 1'b1;

            busy  <= 1'b1;
            done  <= 1'b0;
            error <= 1'b0;
            error_code <= 8'h00;

            init_mode <= 1'b1;

            clock_count <= 0;

            cmd_index <= 0;

            response_count <= 0;

            token_wait_counter <= 0;

            lba <= START_LBA;

            sector_count <= 0;

            ram_addr <= 0;

            word_byte <= 0;
            word_buffer <= 0;

            sd_high_capacity <= 1'b1;
            ocr1 <= 0;

        end
        else begin

            case (state)

                // ----------------------------------------------------
                // RESET
                // ----------------------------------------------------

                ST_RESET: begin

                    busy <= 1'b1;
                    done <= 1'b0;
                    error <= 1'b0;

                    init_mode <= 1'b1;

                    sd_cs_n <= 1'b1;

                    clock_count <= 0;

                    if (sd_cd_n) begin
                        error_code <= 8'h02;
                        state <= ST_ERROR;
                    end
                    else begin
                        state <= ST_CLOCK_80;
                    end
                end

                // ----------------------------------------------------
                // At least 74 clocks with CS HIGH
                //
                // 10 × 8 = 80 clocks
                // ----------------------------------------------------

                ST_CLOCK_80: begin

                    sd_cs_n <= 1'b1;

                    if (spi_done) begin

                        if (clock_count == 9) begin

                            clock_count <= 0;

                            state <= ST_CMD0_START;

                        end
                        else begin

                            clock_count <= clock_count + 1'b1;

                        end
                    end
                end

                // ----------------------------------------------------
                // CMD0
                //
                // 40 00 00 00 00 95
                // ----------------------------------------------------

                ST_CMD0_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h40;
                    cmd_buf[1] <= 8'h00;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h00;
                    cmd_buf[4] <= 8'h00;
                    cmd_buf[5] <= 8'h95;

                    cmd_index <= 0;

                    state <= ST_CMD0_SEND;
                end

                ST_CMD0_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_CMD0_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_CMD0_WAIT: begin

                    if (spi_done) begin

                        if (rx_byte != 8'hFF) begin

                            if (rx_byte == 8'h01) begin

                                sd_cs_n <= 1'b1;

                                state <= ST_CMD8_START;
                            end
                            else begin
                                error_code <= 8'h01;
                                state <= ST_ERROR;
                            end

                        end
                        else if (response_count == 8'd16) begin

                            error_code <= 8'h10;
                            state <= ST_ERROR;

                        end
                        else begin

                            response_count <= response_count + 1'b1;

                        end
                    end
                end

                // ----------------------------------------------------
                // CMD8
                //
                // 48 00 00 01 AA 87
                // ----------------------------------------------------

                ST_CMD8_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h48;
                    cmd_buf[1] <= 8'h00;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h01;
                    cmd_buf[4] <= 8'hAA;
                    cmd_buf[5] <= 8'h87;

                    cmd_index <= 0;

                    state <= ST_CMD8_SEND;
                end

                ST_CMD8_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_CMD8_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_CMD8_WAIT: begin

                    if (spi_done) begin

                        if (response_count == 0) begin

                            if (rx_byte == 8'hFF) begin
                                // Keep polling
                            end
                            else begin

                                if (8'h04 == (rx_byte & 8'h04)) begin
                                    // Illegal command.
                                    // This is an old SDSC card.
                                    sd_high_capacity <= 1'b0;

                                    sd_cs_n <= 1'b1;

                                    state <= ST_ACMD41_CMD55_START;
                                end
                                else if (rx_byte == 8'h01) begin

                                    response_count <= 1;

                                end
                                else begin

                                    error_code <= 8'h03;
                                    state <= ST_ERROR;

                                end
                            end
                        end
                        else begin

                            case (response_count)
                                4: begin
                                    sd_cs_n <= 1'b1;
                                    state <= ST_ACMD41_CMD55_START;
                                end

                                default: begin
                                end

                            endcase

                            if (response_count < 4)
                                response_count <= response_count + 1'b1;
                        end
                    end
                end

                // ----------------------------------------------------
                // CMD55
                // ----------------------------------------------------

                ST_ACMD41_CMD55_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h77;
                    cmd_buf[1] <= 8'h00;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h00;
                    cmd_buf[4] <= 8'h00;
                    cmd_buf[5] <= 8'h01;

                    cmd_index <= 0;

                    state <= ST_ACMD41_CMD55_SEND;
                end

                ST_ACMD41_CMD55_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_ACMD41_CMD55_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_ACMD41_CMD55_WAIT: begin

                    if (spi_done) begin

                        if (rx_byte != 8'hFF) begin

                            if ((rx_byte == 8'h01) ||
                                (rx_byte == 8'h00)) begin

                                state <= ST_ACMD41_START;

                            end
                            else begin

                                error_code <= 8'h04;
                                state <= ST_ERROR;

                            end
                        end
                        else if (response_count == 16) begin

                            error_code <= 8'h11;
                            state <= ST_ERROR;

                        end
                        else begin

                            response_count <= response_count + 1'b1;

                        end
                    end
                end

                // ----------------------------------------------------
                // ACMD41
                //
                // HCS = 1
                //
                // 69 40 00 00 00 77
                //
                // Repeat until R1 == 00.
                // ----------------------------------------------------

                ST_ACMD41_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h69;
                    cmd_buf[1] <= 8'h40;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h00;
                    cmd_buf[4] <= 8'h00;
                    cmd_buf[5] <= 8'h77;

                    cmd_index <= 0;

                    state <= ST_ACMD41_SEND;
                end

                ST_ACMD41_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_ACMD41_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_ACMD41_WAIT: begin

                    if (spi_done) begin

                        if (rx_byte != 8'hFF) begin

                            if (rx_byte == 8'h00) begin

                                sd_cs_n <= 1'b1;

                                state <= ST_CMD58_START;

                            end
                            else if (rx_byte == 8'h01) begin

                                // Still initializing.
                                //
                                // Release CS and send CMD55 again.

                                sd_cs_n <= 1'b1;

                                state <= ST_ACMD41_CMD55_START;

                            end
                            else begin

                                error_code <= 8'h05;
                                state <= ST_ERROR;

                            end
                        end
                        else if (response_count == 8'd64) begin

                            error_code <= 8'h06;
                            state <= ST_ERROR;

                        end
                        else begin

                            response_count <= response_count + 1'b1;

                        end
                    end
                end

                // ----------------------------------------------------
                // CMD58 - READ OCR
                //
                // 7A 00 00 00 00 75
                // ----------------------------------------------------

                ST_CMD58_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h7A;
                    cmd_buf[1] <= 8'h00;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h00;
                    cmd_buf[4] <= 8'h00;
                    cmd_buf[5] <= 8'h75;

                    cmd_index <= 0;

                    state <= ST_CMD58_SEND;
                end

                ST_CMD58_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_CMD58_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_CMD58_WAIT: begin

                    if (spi_done) begin

                        if (response_count == 0) begin

                            if (rx_byte == 8'hFF) begin
                                // Wait
                            end
                            else begin

                                if (rx_byte != 8'h00) begin
                                    error_code <= 8'h07;
                                    state <= ST_ERROR;
                                end
                                else begin
                                    response_count <= 1;
                                end

                            end
                        end
                        else begin

                            case (response_count)

                                1: ocr1 <= rx_byte;
                                4: begin
                                    // OCR byte 0 bit 6 = CCS
                                    //
                                    // OCR:
                                    // byte 1 = bits 31:24
                                    //
                                    // CCS = OCR[30]
                                    //
                                    if (ocr1[6])
                                        sd_high_capacity <= 1'b1;
                                    else
                                        sd_high_capacity <= 1'b0;

                                    sd_cs_n <= 1'b1;

                                    if (ocr1[6]) begin

                                        // SDHC / SDXC
                                        init_mode <= 1'b0;

                                        lba <= START_LBA;

                                        ram_addr <= 0;

                                        state <= ST_READ_START;

                                    end
                                    else begin

                                        // SDSC requires CMD16.
                                        state <= ST_CMD16_START;

                                    end
                                end

                                default: begin
                                end

                            endcase

                            if (response_count < 4)
                                response_count <= response_count + 1'b1;
                        end
                    end
                end

                // ----------------------------------------------------
                // CMD16 - set block size = 512
                //
                // 50 00 00 02 00 FF
                // ----------------------------------------------------

                ST_CMD16_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h50;
                    cmd_buf[1] <= 8'h00;
                    cmd_buf[2] <= 8'h00;
                    cmd_buf[3] <= 8'h02;
                    cmd_buf[4] <= 8'h00;
                    cmd_buf[5] <= 8'hFF;

                    cmd_index <= 0;

                    state <= ST_CMD16_SEND;
                end

                ST_CMD16_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_CMD16_WAIT;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                ST_CMD16_WAIT: begin

                    if (spi_done) begin

                        if (rx_byte != 8'hFF) begin

                            if (rx_byte == 8'h00) begin

                                sd_cs_n <= 1'b1;

                                init_mode <= 1'b0;

                                lba <= START_LBA;

                                ram_addr <= 0;

                                state <= ST_READ_START;

                            end
                            else begin

                                error_code <= 8'h08;
                                state <= ST_ERROR;
                            end

                        end
                        else if (response_count == 16) begin

                            error_code <= 8'h09;
                            state <= ST_ERROR;

                        end
                        else begin

                            response_count <= response_count + 1'b1;
                        end
                    end
                end

                // ----------------------------------------------------
                // CMD17 - READ SINGLE BLOCK
                // ----------------------------------------------------

                ST_READ_START: begin

                    sd_cs_n <= 1'b0;

                    cmd_buf[0] <= 8'h51;

                    if (sd_high_capacity) begin

                        // SDHC/SDXC:
                        // argument = LBA

                        cmd_buf[1] <= lba[31:24];
                        cmd_buf[2] <= lba[23:16];
                        cmd_buf[3] <= lba[15:8];
                        cmd_buf[4] <= lba[7:0];

                    end
                    else begin

                        // SDSC:
                        // argument = byte address = LBA * 512

                        cmd_buf[1] <= byte_address[31:24];
                        cmd_buf[2] <= byte_address[23:16];
                        cmd_buf[3] <= byte_address[15:8];
                        cmd_buf[4] <= byte_address[7:0];

                    end

                    // CRC is ignored by SD in SPI mode.
                    cmd_buf[5] <= 8'hFF;

                    cmd_index <= 0;

                    state <= ST_READ_SEND;
                end

                ST_READ_SEND: begin

                    if (spi_done) begin

                        if (cmd_index == 5) begin

                            response_count <= 0;

                            state <= ST_READ_WAIT_R1;

                        end
                        else begin

                            cmd_index <= cmd_index + 1'b1;

                        end
                    end
                end

                // ----------------------------------------------------
                // Wait for R1
                // ----------------------------------------------------

                ST_READ_WAIT_R1: begin

                    if (spi_done) begin

                        if (rx_byte != 8'hFF) begin

                            if (rx_byte == 8'h00) begin

                                response_count <= 0;
                                token_wait_counter <= 0;

                                state <= ST_READ_WAIT_TOKEN;

                            end
                            else begin

                                error_code <= 8'h0A;
                                state <= ST_ERROR;

                            end
                        end
                        else if (response_count == 64) begin

                            error_code <= 8'h0B;
                            state <= ST_ERROR;

                        end
                        else begin

                            response_count <= response_count + 1'b1;
                        end
                    end
                end

                // ----------------------------------------------------
                // Wait for data token 0xFE
                // ----------------------------------------------------

                ST_READ_WAIT_TOKEN: begin

                    if (spi_done && (rx_byte == 8'hFE)) begin

                        word_byte <= 0;

                        word_buffer <= 0;

                        state <= ST_READ_DATA;

                    end
                    else if (token_wait_counter >= READ_TOKEN_TIMEOUT_CYCLES) begin
                        error_code <= 8'h0D;
                        state <= ST_ERROR;
                    end
                    else begin
                        token_wait_counter <= token_wait_counter + 1'b1;

                        if (spi_done && (rx_byte != 8'hFF)) begin
                            // Error token
                            error_code <= 8'h0C;
                            state <= ST_ERROR;
                        end
                    end
                end

                // ----------------------------------------------------
                // Read 512 bytes
                //
                // Byte order:
                //
                // byte 0 -> [7:0]
                // byte 1 -> [15:8]
                // byte 2 -> [23:16]
                // byte 3 -> [31:24]
                //
                // This gives little-endian 32-bit words.
                // ----------------------------------------------------

                ST_READ_DATA: begin

                    if (spi_done) begin

                        case (word_byte)

                            2'd0: begin
                                word_buffer[7:0] <= rx_byte;
                                word_byte <= 1;
                            end

                            2'd1: begin
                                word_buffer[15:8] <= rx_byte;
                                word_byte <= 2;
                            end

                            2'd2: begin
                                word_buffer[23:16] <= rx_byte;
                                word_byte <= 3;
                            end

                            2'd3: begin

                                // Direct write to internal RAM.
                                if (ram_addr < RAM_WORDS) begin

                                    ram[ram_addr] <= {
                                        rx_byte,
                                        word_buffer[23:0]
                                    };

                                end
                                else begin

                                    error_code <= 8'h0E;
                                    state <= ST_ERROR;
                                end

                                ram_addr <= ram_addr + 1'b1;

                                word_byte <= 0;

                            end

                        endcase

                        // 512 bytes = 128 words.
                        //
                        // We detect the end after word 127.
                        //
                        if ((word_byte == 2'd3) &&
                            (ram_addr[6:0] == 7'd127)) begin

                            state <= ST_READ_CRC1;

                        end
                    end
                end

                // ----------------------------------------------------
                // Ignore CRC16
                // ----------------------------------------------------

                ST_READ_CRC1: begin

                    if (spi_done) begin
                        state <= ST_READ_CRC2;
                    end

                end

                ST_READ_CRC2: begin

                    if (spi_done) begin

                        sd_cs_n <= 1'b1;

                        state <= ST_NEXT_SECTOR;
                    end

                end

                // ----------------------------------------------------
                // Next sector
                // ----------------------------------------------------

                ST_NEXT_SECTOR: begin

                    // Number of sectors required:
                    //
                    // RAM_WORDS * 4 / 512
                    //
                    // = RAM_WORDS / 128
                    //
                    if (sector_count + 1 >= (RAM_WORDS / 128)) begin

                        state <= ST_DONE;

                    end
                    else begin

                        sector_count <= sector_count + 1'b1;

                        lba <= lba + 1'b1;

                        state <= ST_READ_START;

                    end
                end

                // ----------------------------------------------------
                // DONE
                // ----------------------------------------------------

                ST_DONE: begin

                    sd_cs_n <= 1'b1;

                    busy  <= 1'b0;
                    done  <= 1'b1;
                    error <= 1'b0;

                    state <= ST_DONE;
                end

                // ----------------------------------------------------
                // ERROR
                // ----------------------------------------------------

                ST_ERROR: begin

                    sd_cs_n <= 1'b1;

                    busy  <= 1'b0;
                    done  <= 1'b0;
                    error <= 1'b1;

                    state <= ST_ERROR;
                end

                default: begin

                    error_code <= 8'h0F;
                    state <= ST_ERROR;

                end

            endcase
        end
    end

endmodule
