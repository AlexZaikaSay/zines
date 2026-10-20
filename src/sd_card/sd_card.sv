// SD card controller, SPI mode. Low level: runs one operation per request
// (init, read one sector, write one sector) and returns to idle.
//
// Request: pulse req with op/lba while ready. The op ends with a one-cycle
// done or error pulse; error_code holds the reason until the next request.
//
// Sector data is streamed by byte index so the owner can use a plain buffer:
//   read:  rd_valid/rd_index/rd_data, one pulse per received byte
//   write: sd_card drives wr_index and expects wr_data = buffer[wr_index]
//          combinationally
module sd_card #(
    // FPGA clock
    parameter integer CLK_FREQ_HZ = 50_000_000,

    // SPI clock during initialization. Must be <= 400 kHz.
    parameter integer INIT_SPI_HZ = 400_000,

    // SPI clock after initialization.
    parameter integer RUN_SPI_HZ  = 10_000_000,

    // Maximum wait for the read data token after CMD17 returns R1.
    parameter integer READ_TOKEN_TIMEOUT_MS = 100,

    // Maximum time the card may stay busy after a write.
    parameter integer WRITE_BUSY_TIMEOUT_MS = 500,

    // ACMD41 attempts before giving up (card leaves idle state).
    parameter integer ACMD41_MAX_TRIES = 4000
)(
    input  logic        clk,
    input  logic        reset_n,

    // SD card SPI interface
    output logic        sd_clk,
    output logic        sd_cmd,       // MOSI
    input  logic        sd_dat0,      // MISO
    output logic        sd_cs_n,
    input  logic        sd_cd_n,      // Card detect, active low

    // Request
    input  logic        req,
    input  logic [1:0]  op,
    input  logic [31:0] lba,
    output logic        ready,        // idle, accepts req
    output logic        done,         // pulse: op finished OK
    output logic        error,        // pulse: op failed
    output logic [7:0]  error_code,
    output logic        initialized,  // last init succeeded
    output logic        sdhc,         // block addressing card

    // Read stream (card -> buffer)
    output logic        rd_valid,
    output logic [8:0]  rd_index,
    output logic [7:0]  rd_data,

    // Write stream (buffer -> card)
    output logic [8:0]  wr_index,
    input  logic [7:0]  wr_data
);

    localparam logic [1:0] OP_INIT  = 2'd0;
    localparam logic [1:0] OP_READ  = 2'd1;
    localparam logic [1:0] OP_WRITE = 2'd2;

    // error_code values
    localparam logic [7:0] E_NO_CARD        = 8'h01;
    localparam logic [7:0] E_NOT_INIT       = 8'h02;
    localparam logic [7:0] E_BAD_OP         = 8'h03;
    localparam logic [7:0] E_R1_TIMEOUT     = 8'h10;  // no R1 after a command
    localparam logic [7:0] E_CMD0           = 8'h11;
    localparam logic [7:0] E_CMD8           = 8'h12;
    localparam logic [7:0] E_CMD55          = 8'h13;
    localparam logic [7:0] E_ACMD41         = 8'h14;
    localparam logic [7:0] E_ACMD41_TIMEOUT = 8'h15;
    localparam logic [7:0] E_CMD58          = 8'h16;
    localparam logic [7:0] E_CMD16          = 8'h17;
    localparam logic [7:0] E_READ_R1        = 8'h20;
    localparam logic [7:0] E_READ_TOKEN     = 8'h21;  // error token instead of FE
    localparam logic [7:0] E_READ_TIMEOUT   = 8'h22;
    localparam logic [7:0] E_WRITE_R1       = 8'h30;
    localparam logic [7:0] E_WRITE_REJECT   = 8'h31;  // data response != 05
    localparam logic [7:0] E_WRITE_TIMEOUT  = 8'h32;

    // ================================================================
    // SPI clock divider
    // ================================================================

    localparam integer INIT_DIV =
        ((CLK_FREQ_HZ + (INIT_SPI_HZ * 2) - 1) / (INIT_SPI_HZ * 2));

    localparam integer RUN_DIV =
        ((CLK_FREQ_HZ + (RUN_SPI_HZ * 2) - 1) / (RUN_SPI_HZ * 2));

    localparam integer READ_TOKEN_TIMEOUT_CYCLES =
        (CLK_FREQ_HZ / 1000) * READ_TOKEN_TIMEOUT_MS;

    localparam integer WRITE_BUSY_TIMEOUT_CYCLES =
        (CLK_FREQ_HZ / 1000) * WRITE_BUSY_TIMEOUT_MS;

    localparam integer MAX_DIV = (INIT_DIV > RUN_DIV) ? INIT_DIV : RUN_DIV;

    localparam integer DIV_W = (MAX_DIV <= 1) ? 1 : $clog2(MAX_DIV + 1);

    logic   init_mode;
    integer current_div;

    always_comb begin
        current_div = init_mode ? INIT_DIV : RUN_DIV;
        if (current_div < 1)
            current_div = 1;
    end

    // ================================================================
    // SPI byte engine, mode 0 (CPOL = 0, CPHA = 0):
    // data sampled on the rising edge, changed on the falling edge.
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
            sd_clk         <= 1'b0;
            sd_cmd         <= 1'b1;
            spi_tx_latched <= 8'hFF;
            spi_rx         <= 8'h00;
            spi_active     <= 1'b0;
            spi_done       <= 1'b0;
            spi_bit        <= 3'd7;
            spi_cnt        <= '0;
        end
        else begin
            spi_done <= 1'b0;

            if (spi_start && !spi_active) begin
                spi_active     <= 1'b1;
                spi_bit        <= 3'd7;
                spi_tx_latched <= spi_tx;
                spi_rx         <= 8'h00;
                sd_clk         <= 1'b0;
                sd_cmd         <= spi_tx[7];
                spi_cnt        <= '0;
            end
            else if (spi_active) begin
                if (spi_cnt >= DIV_W'(current_div - 1)) begin
                    spi_cnt <= '0;

                    if (sd_clk == 1'b0) begin
                        // Rising edge: sample MISO
                        sd_clk          <= 1'b1;
                        spi_rx[spi_bit] <= sd_dat0;
                    end
                    else begin
                        // Falling edge: next bit
                        sd_clk <= 1'b0;
                        if (spi_bit == 0) begin
                            spi_active <= 1'b0;
                            spi_done   <= 1'b1;
                            sd_cmd     <= 1'b1;     // MOSI idle high
                        end
                        else begin
                            spi_bit <= spi_bit - 1'b1;
                            sd_cmd  <= spi_tx_latched[spi_bit - 1'b1];
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
    // Controller
    //
    // Every command goes through ST_CMD (send 6 bytes) and ST_CMD_R1 (poll
    // for R1, then read resp_extra more bytes into resp). The FSM then
    // continues at ret_state, which checks r1/resp and picks the next step.
    // ================================================================

    typedef enum logic [4:0] {
        ST_IDLE,
        ST_DESELECT,        // CS high + 8 clocks, then idle

        ST_CMD,
        ST_CMD_R1,
        ST_CMD_RESP,

        ST_INIT_CLOCKS,     // >= 74 clocks with CS high
        ST_INIT_CMD0,
        ST_INIT_CMD8,
        ST_INIT_CMD55,
        ST_INIT_ACMD41,
        ST_INIT_CMD58,
        ST_INIT_CMD16,

        ST_READ_CMD17,
        ST_READ_TOKEN,
        ST_READ_DATA,
        ST_READ_CRC,

        ST_WRITE_CMD24,
        ST_WRITE_GAP,       // one FF before the start token
        ST_WRITE_TOKEN,     // FE
        ST_WRITE_DATA,
        ST_WRITE_CRC,
        ST_WRITE_RESP,      // data response xxx0_0101
        ST_WRITE_BUSY       // card holds MISO low while programming
    } state_t;

    state_t state;
    state_t ret_state;

    logic [7:0]  cmd_buf [0:5];
    logic [2:0]  cmd_index;
    logic [2:0]  resp_extra;    // bytes after R1 (R3/R7: 4)
    logic [7:0]  r1;
    logic [31:0] resp;

    logic [7:0]  poll_count;
    logic [31:0] timer;
    logic [15:0] tries;
    logic [9:0]  byte_count;

    logic [31:0] lba_r;
    logic        sd_v2;         // card answered CMD8
    logic        op_ok;         // result reported from ST_DESELECT

    // Byte to clock out in the current state; spi_start whenever the state
    // needs a byte and the engine is free.
    always_comb begin
        case (state)
            ST_CMD:        spi_tx = cmd_buf[cmd_index];
            ST_WRITE_TOKEN: spi_tx = 8'hFE;
            ST_WRITE_DATA: spi_tx = wr_data;
            default:       spi_tx = 8'hFF;
        endcase

        spi_start = !spi_active && !spi_done &&
                    state != ST_IDLE &&
                    !(state == ST_INIT_CMD0 || state == ST_INIT_CMD8 ||
                      state == ST_INIT_CMD55 || state == ST_INIT_ACMD41 ||
                      state == ST_INIT_CMD58 || state == ST_INIT_CMD16 ||
                      state == ST_READ_CMD17 || state == ST_WRITE_CMD24);
    end

    assign ready    = (state == ST_IDLE) && !req;
    assign wr_index = byte_count[8:0];

    // The tasks below are called only from the controller always_ff, but
    // the linter counts them as a separate process.
    /* verilator lint_off MULTIDRIVEN */

    // Queue a command; the FSM continues at ret after R1 (+ extra bytes)
    task automatic send_cmd(input logic [5:0] index, input logic [31:0] arg,
                            input logic [7:0] crc, input logic [2:0] extra,
                            input state_t ret);
        cmd_buf[0] <= {2'b01, index};
        cmd_buf[1] <= arg[31:24];
        cmd_buf[2] <= arg[23:16];
        cmd_buf[3] <= arg[15:8];
        cmd_buf[4] <= arg[7:0];
        cmd_buf[5] <= crc;
        cmd_index  <= 0;
        resp_extra <= extra;
        ret_state  <= ret;
        sd_cs_n    <= 1'b0;
        state      <= ST_CMD;
    endtask

    task automatic finish(input logic ok, input logic [7:0] code);
        op_ok <= ok;
        if (!ok)
            error_code <= code;
        state <= ST_DESELECT;
    endtask

    // Command argument: block number for SDHC, byte address for SDSC
    wire [31:0] addr_arg = sdhc ? lba_r : (lba_r << 9);

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state       <= ST_IDLE;
            ret_state   <= ST_IDLE;
            sd_cs_n     <= 1'b1;
            init_mode   <= 1'b1;
            done        <= 1'b0;
            error       <= 1'b0;
            error_code  <= 8'h00;
            initialized <= 1'b0;
            sdhc        <= 1'b0;
            sd_v2       <= 1'b0;
            op_ok       <= 1'b0;
            cmd_index   <= 0;
            resp_extra  <= 0;
            r1          <= 8'hFF;
            resp        <= 0;
            poll_count  <= 0;
            timer       <= 0;
            tries       <= 0;
            byte_count  <= 0;
            lba_r       <= 0;
            rd_valid    <= 1'b0;
            rd_index    <= 0;
            rd_data     <= 8'h00;
        end
        else begin
            done     <= 1'b0;
            error    <= 1'b0;
            rd_valid <= 1'b0;

            case (state)

                // ----------------------------------------------------
                // Wait for a request
                // ----------------------------------------------------
                ST_IDLE: begin
                    sd_cs_n <= 1'b1;
                    if (req) begin
                        lba_r      <= lba;
                        error_code <= 8'h00;
                        if (sd_cd_n)
                            finish(1'b0, E_NO_CARD);
                        else case (op)
                            OP_INIT: begin
                                initialized <= 1'b0;
                                init_mode   <= 1'b1;
                                sdhc        <= 1'b0;
                                byte_count  <= 0;
                                state       <= ST_INIT_CLOCKS;
                            end
                            OP_READ:  if (initialized) state <= ST_READ_CMD17;
                                      else finish(1'b0, E_NOT_INIT);
                            OP_WRITE: if (initialized) state <= ST_WRITE_CMD24;
                                      else finish(1'b0, E_NOT_INIT);
                            default:  finish(1'b0, E_BAD_OP);
                        endcase
                    end
                end

                // ----------------------------------------------------
                // End of an operation: CS high, 8 clocks, report
                // ----------------------------------------------------
                ST_DESELECT: begin
                    sd_cs_n <= 1'b1;
                    if (spi_done) begin
                        done  <= op_ok;
                        error <= !op_ok;
                        state <= ST_IDLE;
                    end
                end

                // ----------------------------------------------------
                // Shared command sender
                // ----------------------------------------------------
                ST_CMD: begin
                    if (spi_done) begin
                        if (cmd_index == 5) begin
                            poll_count <= 0;
                            state      <= ST_CMD_R1;
                        end
                        else
                            cmd_index <= cmd_index + 1'b1;
                    end
                end

                ST_CMD_R1: begin
                    if (spi_done) begin
                        if (spi_rx != 8'hFF) begin
                            r1         <= spi_rx;
                            resp       <= 0;
                            // An error R1 has no payload
                            if (resp_extra != 0 && spi_rx[7:1] == 0)
                                state <= ST_CMD_RESP;
                            else
                                state <= ret_state;
                        end
                        else if (poll_count == 8'd16)
                            finish(1'b0, E_R1_TIMEOUT);
                        else
                            poll_count <= poll_count + 1'b1;
                    end
                end

                ST_CMD_RESP: begin
                    if (spi_done) begin
                        resp       <= {resp[23:0], spi_rx};
                        resp_extra <= resp_extra - 1'b1;
                        if (resp_extra == 1)
                            state <= ret_state;
                    end
                end

                // ----------------------------------------------------
                // Init: 80 clocks, CMD0, CMD8, (CMD55 + ACMD41)*, CMD58,
                // CMD16 for byte-addressed cards
                // ----------------------------------------------------
                ST_INIT_CLOCKS: begin
                    sd_cs_n <= 1'b1;
                    if (spi_done) begin
                        if (byte_count == 9)
                            send_cmd(6'd0, 32'h0, 8'h95, 3'd0, ST_INIT_CMD0);
                        else
                            byte_count <= byte_count + 1'b1;
                    end
                end

                ST_INIT_CMD0: begin
                    if (r1 == 8'h01)
                        send_cmd(6'd8, 32'h0000_01AA, 8'h87, 3'd4, ST_INIT_CMD8);
                    else
                        finish(1'b0, E_CMD0);
                end

                ST_INIT_CMD8: begin
                    tries <= 0;
                    if (r1[2]) begin
                        // Illegal command: SD v1 card
                        sd_v2 <= 1'b0;
                        send_cmd(6'd55, 32'h0, 8'h65, 3'd0, ST_INIT_CMD55);
                    end
                    else if (r1 == 8'h01 && resp[11:0] == 12'h1AA) begin
                        sd_v2 <= 1'b1;
                        send_cmd(6'd55, 32'h0, 8'h65, 3'd0, ST_INIT_CMD55);
                    end
                    else
                        finish(1'b0, E_CMD8);
                end

                ST_INIT_CMD55: begin
                    if (r1[7:1] == 0)
                        // HCS = 1 for v2 cards
                        send_cmd(6'd41, sd_v2 ? 32'h4000_0000 : 32'h0, 8'h77,
                                 3'd0, ST_INIT_ACMD41);
                    else
                        finish(1'b0, E_CMD55);
                end

                ST_INIT_ACMD41: begin
                    if (r1 == 8'h00) begin
                        if (sd_v2)
                            send_cmd(6'd58, 32'h0, 8'hFD, 3'd4, ST_INIT_CMD58);
                        else
                            send_cmd(6'd16, 32'd512, 8'h15, 3'd0, ST_INIT_CMD16);
                    end
                    else if (r1 == 8'h01) begin
                        // Still initializing
                        if (tries == 16'(ACMD41_MAX_TRIES - 1))
                            finish(1'b0, E_ACMD41_TIMEOUT);
                        else begin
                            tries <= tries + 1'b1;
                            send_cmd(6'd55, 32'h0, 8'h65, 3'd0, ST_INIT_CMD55);
                        end
                    end
                    else
                        finish(1'b0, E_ACMD41);
                end

                ST_INIT_CMD58: begin
                    if (r1 != 8'h00)
                        finish(1'b0, E_CMD58);
                    else if (resp[30]) begin
                        // CCS = 1: SDHC/SDXC, block addressing
                        sdhc        <= 1'b1;
                        initialized <= 1'b1;
                        init_mode   <= 1'b0;
                        finish(1'b1, 8'h00);
                    end
                    else
                        send_cmd(6'd16, 32'd512, 8'h15, 3'd0, ST_INIT_CMD16);
                end

                ST_INIT_CMD16: begin
                    if (r1 == 8'h00) begin
                        initialized <= 1'b1;
                        init_mode   <= 1'b0;
                        finish(1'b1, 8'h00);
                    end
                    else
                        finish(1'b0, E_CMD16);
                end

                // ----------------------------------------------------
                // Read one sector: CMD17, token FE, 512 bytes, CRC16
                // ----------------------------------------------------
                ST_READ_CMD17: begin
                    send_cmd(6'd17, addr_arg, 8'hFF, 3'd0, ST_READ_TOKEN);
                    timer <= 0;
                end

                ST_READ_TOKEN: begin
                    if (r1 != 8'h00)
                        finish(1'b0, E_READ_R1);
                    else if (spi_done && spi_rx == 8'hFE) begin
                        byte_count <= 0;
                        state      <= ST_READ_DATA;
                    end
                    else if (spi_done && spi_rx != 8'hFF)
                        finish(1'b0, E_READ_TOKEN);
                    else if (timer >= READ_TOKEN_TIMEOUT_CYCLES)
                        finish(1'b0, E_READ_TIMEOUT);
                    else
                        timer <= timer + 1'b1;
                end

                ST_READ_DATA: begin
                    if (spi_done) begin
                        rd_valid   <= 1'b1;
                        rd_index   <= byte_count[8:0];
                        rd_data    <= spi_rx;
                        byte_count <= byte_count + 1'b1;
                        if (byte_count == 511) begin
                            byte_count <= 0;
                            state      <= ST_READ_CRC;
                        end
                    end
                end

                ST_READ_CRC: begin
                    // CRC16 is ignored
                    if (spi_done) begin
                        byte_count <= byte_count + 1'b1;
                        if (byte_count == 1)
                            finish(1'b1, 8'h00);
                    end
                end

                // ----------------------------------------------------
                // Write one sector: CMD24, gap, token FE, 512 bytes, CRC16,
                // data response, wait while busy
                // ----------------------------------------------------
                ST_WRITE_CMD24: begin
                    send_cmd(6'd24, addr_arg, 8'hFF, 3'd0, ST_WRITE_GAP);
                end

                ST_WRITE_GAP: begin
                    if (r1 != 8'h00)
                        finish(1'b0, E_WRITE_R1);
                    else if (spi_done)
                        state <= ST_WRITE_TOKEN;
                end

                ST_WRITE_TOKEN: begin
                    if (spi_done) begin
                        byte_count <= 0;
                        state      <= ST_WRITE_DATA;
                    end
                end

                ST_WRITE_DATA: begin
                    if (spi_done) begin
                        byte_count <= byte_count + 1'b1;
                        if (byte_count == 511) begin
                            byte_count <= 0;
                            state      <= ST_WRITE_CRC;
                        end
                    end
                end

                ST_WRITE_CRC: begin
                    // Dummy CRC16 (FF FF); not checked in SPI mode
                    if (spi_done) begin
                        byte_count <= byte_count + 1'b1;
                        if (byte_count == 1) begin
                            poll_count <= 0;
                            state      <= ST_WRITE_RESP;
                        end
                    end
                end

                ST_WRITE_RESP: begin
                    if (spi_done) begin
                        if (spi_rx != 8'hFF) begin
                            if (spi_rx[4:0] == 5'b00101) begin
                                timer <= 0;
                                state <= ST_WRITE_BUSY;
                            end
                            else
                                finish(1'b0, E_WRITE_REJECT);
                        end
                        else if (poll_count == 8'd16)
                            finish(1'b0, E_WRITE_REJECT);
                        else
                            poll_count <= poll_count + 1'b1;
                    end
                end

                ST_WRITE_BUSY: begin
                    if (spi_done && spi_rx == 8'hFF)
                        finish(1'b1, 8'h00);
                    else if (timer >= WRITE_BUSY_TIMEOUT_CYCLES)
                        finish(1'b0, E_WRITE_TIMEOUT);
                    else
                        timer <= timer + 1'b1;
                end

                default: finish(1'b0, E_BAD_OP);

            endcase
        end
    end
    /* verilator lint_on MULTIDRIVEN */

endmodule
