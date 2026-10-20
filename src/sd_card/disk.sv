`include "sd_card/sd_card.sv"

// SD disk: CPU-facing command processor on top of sd_card.
//
// Registers (reg_sel, offset = reg_addr):
//   0 SD_CMD      W: 1 = init, 2 = read SD_LBA -> buffer, 3 = write buffer -> SD_LBA
//   1 SD_STATUS   R: SD_BUSY | SD_ERROR | SD_READY | SD_SDHC
//   2 SD_ERRCODE  R: sd_card error code of the last failed command
//   4..7 SD_LBA   RW: sector number, little-endian
//
// The 512-byte sector buffer lives outside (any RAM with async read). While
// buf_active is set disk drives it through buf_*; otherwise it belongs to
// the CPU. The CPU should not touch it while SD_BUSY is set.
//
// A command written while busy is ignored. SD_ERROR is cleared by the next
// command.
module disk #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer INIT_SPI_HZ = 400_000,
    parameter integer RUN_SPI_HZ  = 10_000_000
)(
    input  logic        clk,
    input  logic        rst_n,

    // CPU bus
    input  logic        reg_sel,
    input  logic [2:0]  reg_addr,
    input  logic        rw,         // 1 = read
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out,

    // Sector buffer
    output logic        buf_active,
    output logic [8:0]  buf_addr,
    output logic        buf_we,
    output logic [7:0]  buf_wdata,
    input  logic [7:0]  buf_rdata,

    // SD card SPI interface
    output logic        sd_clk,
    output logic        sd_cmd,     // MOSI
    input  logic        sd_dat0,    // MISO
    output logic        sd_cs_n,
    input  logic        sd_cd_n     // Card detect, active low
);

    localparam logic [7:0] SD_BUSY  = 8'h01;
    localparam logic [7:0] SD_ERROR = 8'h02;
    localparam logic [7:0] SD_READY = 8'h04;    // init done
    localparam logic [7:0] SD_SDHC  = 8'h08;    // block addressing (info only)

    localparam logic [7:0] SD_CMD_INIT  = 8'h01;
    localparam logic [7:0] SD_CMD_READ  = 8'h02;
    localparam logic [7:0] SD_CMD_WRITE = 8'h03;

    localparam logic [2:0] REG_CMD     = 3'd0;
    localparam logic [2:0] REG_STATUS  = 3'd1;
    localparam logic [2:0] REG_ERRCODE = 3'd2;
    localparam logic [2:0] REG_LBA0    = 3'd4;
    localparam logic [2:0] REG_LBA1    = 3'd5;
    localparam logic [2:0] REG_LBA2    = 3'd6;
    localparam logic [2:0] REG_LBA3    = 3'd7;

    // sd_card ops
    localparam logic [1:0] OP_INIT  = 2'd0;
    localparam logic [1:0] OP_READ  = 2'd1;
    localparam logic [1:0] OP_WRITE = 2'd2;

    logic [31:0] lba;
    logic        req;
    logic [1:0]  op;
    logic        busy;
    logic        failed;

    logic        sd_ready;
    logic        sd_done;
    logic        sd_error;
    logic [7:0]  sd_error_code;
    logic        sd_initialized;
    logic        sd_sdhc;

    logic        rd_valid;
    logic [8:0]  rd_index;
    logic [7:0]  rd_data;
    logic [8:0]  wr_index;

    sd_card #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .INIT_SPI_HZ(INIT_SPI_HZ),
        .RUN_SPI_HZ(RUN_SPI_HZ)
    ) sd_inst (
        .clk(clk),
        .reset_n(rst_n),
        .sd_clk(sd_clk),
        .sd_cmd(sd_cmd),
        .sd_dat0(sd_dat0),
        .sd_cs_n(sd_cs_n),
        .sd_cd_n(sd_cd_n),
        .req(req),
        .op(op),
        .lba(lba),
        .ready(sd_ready),
        .done(sd_done),
        .error(sd_error),
        .error_code(sd_error_code),
        .initialized(sd_initialized),
        .sdhc(sd_sdhc),
        .rd_valid(rd_valid),
        .rd_index(rd_index),
        .rd_data(rd_data),
        .wr_index(wr_index),
        .wr_data(buf_rdata)
    );

    wire reg_write = reg_sel && !rw;
    wire cmd_write = reg_write && reg_addr == REG_CMD;

    // ---------------- Commands and registers ----------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lba    <= 0;
            req    <= 1'b0;
            op     <= OP_INIT;
            busy   <= 1'b0;
            failed <= 1'b0;
        end
        else begin
            req <= 1'b0;

            if (sd_done || sd_error) begin
                busy   <= 1'b0;
                failed <= sd_error;
            end

            if (cmd_write && !busy && sd_ready) begin
                case (data_in)
                    SD_CMD_INIT:  begin op <= OP_INIT;  req <= 1'b1; busy <= 1'b1; failed <= 1'b0; end
                    SD_CMD_READ:  begin op <= OP_READ;  req <= 1'b1; busy <= 1'b1; failed <= 1'b0; end
                    SD_CMD_WRITE: begin op <= OP_WRITE; req <= 1'b1; busy <= 1'b1; failed <= 1'b0; end
                    default: ;
                endcase
            end

            // LBA is latched by sd_card on req, so it may change while busy
            if (reg_write) begin
                case (reg_addr)
                    REG_LBA0: lba[7:0]   <= data_in;
                    REG_LBA1: lba[15:8]  <= data_in;
                    REG_LBA2: lba[23:16] <= data_in;
                    REG_LBA3: lba[31:24] <= data_in;
                    default: ;
                endcase
            end
        end
    end

    // ---------------- Sector buffer ----------------
    // Reads store rd_data at rd_index; writes fetch buf_rdata at wr_index
    assign buf_active = busy;
    assign buf_addr   = rd_valid ? rd_index : wr_index;
    assign buf_we     = rd_valid;
    assign buf_wdata  = rd_data;

    // ---------------- CPU read ----------------
    wire [7:0] status = (busy           ? SD_BUSY  : 8'h00) |
                        (failed         ? SD_ERROR : 8'h00) |
                        (sd_initialized ? SD_READY : 8'h00) |
                        (sd_sdhc        ? SD_SDHC  : 8'h00);

    always_comb begin
        data_out = 8'h00;
        if (reg_sel) begin
            case (reg_addr)
                REG_STATUS:  data_out = status;
                REG_ERRCODE: data_out = sd_error_code;
                REG_LBA0:    data_out = lba[7:0];
                REG_LBA1:    data_out = lba[15:8];
                REG_LBA2:    data_out = lba[23:16];
                REG_LBA3:    data_out = lba[31:24];
                default:     data_out = 8'h00;
            endcase
        end
    end

endmodule
