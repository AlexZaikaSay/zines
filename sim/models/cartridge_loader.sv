// Simulation-only loader for cartridge: reads an iNES file at time 0 and,
// after reset, streams it into the cartridge init port one write per clock:
//   fill_w vertical, prg_banks, chr_banks, then PRG bytes (prg_data),
//   then CHR bytes (chr_data). done goes high when everything is written,
//   or right away with a nonzero error_code if the file is rejected.
//
// Supports what cartridge supports: mapper 0, 16/32 KiB PRG,
// 0/8 KiB CHR, no four-screen. A trainer is skipped.
module cartridge_loader #(
    parameter string  ROM_FILE       = "../assets/SMB.nes",
    parameter integer MAX_FILE_BYTES = 16 + 512 + 32768 + 8192
)(
    input  logic        clk,
    input  logic        rst_n,

    // cartridge init port
    output logic [2:0]  fill_w,
    output logic [14:0] addr,
    output logic [7:0]  data,

    // Status
    output logic        done,
    output logic [7:0]  error_code
);
    import zines_pkg::*;

    localparam logic [7:0] E_OPEN      = 8'h20;    // missing file or not iNES
    localparam logic [7:0] E_MAPPER    = 8'h21;
    localparam logic [7:0] E_SIZE      = 8'h22;
    localparam logic [7:0] E_FOUR_SCR  = 8'h23;
    localparam logic [7:0] E_TRUNCATED = 8'h24;

    logic [7:0] image [0:MAX_FILE_BYTES-1];

    integer prg_size;
    integer chr_size;
    integer prg_start;      // file offset of PRG (after header and trainer)

    // ---------------- Header ----------------
    initial begin
        integer     fd;
        integer     bytes_read;
        logic [7:0] mapper;

        error_code = 0;
        prg_size   = 0;
        chr_size   = 0;
        prg_start  = 16;
        bytes_read = 0;

        fd = $fopen(ROM_FILE, "rb");
        if (fd != 0) begin
            bytes_read = $fread(image, fd);
            $fclose(fd);
        end

        if (bytes_read < 16 ||
            image[0] != 8'h4E || image[1] != 8'h45 ||
            image[2] != 8'h53 || image[3] != 8'h1A) begin
            error_code = E_OPEN;
            $display("cartridge_loader: %s is missing or not an iNES file", ROM_FILE);
        end
        else begin
            mapper    = {image[7][7:4], image[6][7:4]};
            prg_start = image[6][2] ? 16 + 512 : 16;
            prg_size  = image[4] * 16384;
            chr_size  = image[5] * 8192;

            if (mapper != 8'd0) begin
                error_code = E_MAPPER;
                $display("cartridge_loader: only mapper 0 is supported, got %0d", mapper);
            end
            else if (image[6][3]) begin
                error_code = E_FOUR_SCR;
                $display("cartridge_loader: four-screen mirroring is not supported");
            end
            else if (image[4] == 8'd0 || image[4] > 8'd2 || image[5] > 8'd1) begin
                error_code = E_SIZE;
                $display("cartridge_loader: unsupported ROM size");
            end
            else if (bytes_read < prg_start + prg_size + chr_size) begin
                error_code = E_TRUNCATED;
                $display("cartridge_loader: %s is truncated", ROM_FILE);
            end
        end
    end

    // ---------------- Write FSM ----------------
    typedef enum logic [2:0] {
        LOAD_VERTICAL,
        LOAD_PRG_BANKS,
        LOAD_CHR_BANKS,
        LOAD_PRG,
        LOAD_CHR,
        LOAD_DONE
    } state_t;

    state_t state;
    integer byte_index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= LOAD_VERTICAL;
            byte_index <= 0;
            done       <= 0;
            fill_w     <= FILL_NONE;
            addr       <= 0;
            data       <= 0;
        end
        else begin
            fill_w <= FILL_NONE;
            case (state)
                LOAD_VERTICAL: begin
                    // Nothing is written for a bad file; done stays low
                    if (error_code == 0) begin
                        fill_w <= FILL_VERTICAL;
                        data[0] <= image[6][0];
                        state <= LOAD_PRG_BANKS;
                    end
                    else
                        state <= LOAD_DONE;
                end
                LOAD_PRG_BANKS: begin
                    fill_w <= FILL_PRG_BANKS;
                    data <= image[4];
                    state <= LOAD_CHR_BANKS;
                end
                LOAD_CHR_BANKS: begin
                    fill_w <= FILL_CHR_BANKS;
                    data <= image[5];
                    state <= LOAD_PRG;
                end
                LOAD_PRG: begin
                    fill_w <= FILL_PRG_DATA;
                    if (byte_index < prg_size) begin
                        addr  <= 15'(byte_index);
                        data  <= image[prg_start + byte_index];
                        byte_index <= byte_index + 1;
                    end
                    else begin
                        byte_index <= 0;
                        state      <= LOAD_CHR;
                    end
                end
                LOAD_CHR: begin
                    fill_w <= FILL_CHR_DATA;
                    if (byte_index < chr_size) begin
                        addr  <= 15'(byte_index);
                        data  <= image[prg_start + prg_size + byte_index];
                        byte_index <= byte_index + 1;
                    end
                    else
                        state <= LOAD_DONE;
                end
                LOAD_DONE: done <= 1;
                default: state <= LOAD_DONE;
            endcase
        end
    end

endmodule
