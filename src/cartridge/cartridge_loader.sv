// Simulation-only loader for cartridge_new: reads an iNES file at time 0 and,
// after reset, streams it into the cartridge init port one byte per clock:
//   one set_w pulse (prg_banks/chr_banks/vertical), then PRG bytes (prg_w),
//   then CHR bytes (chr_w). done goes high when everything is written.
//
// Supports what cartridge_new supports: mapper 0, 16/32 KiB PRG,
// 0/8 KiB CHR, no four-screen. A trainer is skipped.
module cartridge_loader #(
    parameter string  ROM_FILE       = "../assets/SMB.nes",
    parameter integer MAX_FILE_BYTES = 16 + 512 + 32768 + 8192
)(
    input  logic        clk,
    input  logic        rst_n,

    // cartridge_new init port
    output logic        set_w,
    output logic        prg_w,
    output logic        chr_w,
    output logic [7:0]  prg_banks,
    output logic [7:0]  chr_banks,
    output logic        vertical,
    output logic [14:0] init_addr,
    output logic [7:0]  init_data,

    // Status
    output logic        done,
    output logic        error,
    output logic [7:0]  error_code
);
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

        error      = 1'b0;
        error_code = 8'h00;
        prg_banks  = 8'd0;
        chr_banks  = 8'd0;
        vertical   = 1'b0;
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
            error = 1'b1; error_code = E_OPEN;
            $display("cartridge_file_loader: %s is missing or not an iNES file", ROM_FILE);
        end
        else begin
            mapper    = {image[7][7:4], image[6][7:4]};
            prg_banks = image[4];
            chr_banks = image[5];
            vertical  = image[6][0];
            prg_start = image[6][2] ? 16 + 512 : 16;
            prg_size  = image[4] * 16384;
            chr_size  = image[5] * 8192;

            if (mapper != 8'd0) begin
                error = 1'b1; error_code = E_MAPPER;
                $display("cartridge_file_loader: only mapper 0 is supported, got %0d", mapper);
            end
            else if (image[6][3]) begin
                error = 1'b1; error_code = E_FOUR_SCR;
                $display("cartridge_file_loader: four-screen mirroring is not supported");
            end
            else if (image[4] == 8'd0 || image[4] > 8'd2 || image[5] > 8'd1) begin
                error = 1'b1; error_code = E_SIZE;
                $display("cartridge_file_loader: unsupported ROM size");
            end
            else if (bytes_read < prg_start + prg_size + chr_size) begin
                error = 1'b1; error_code = E_TRUNCATED;
                $display("cartridge_file_loader: %s is truncated", ROM_FILE);
            end
        end
    end

    // ---------------- Write FSM ----------------
    typedef enum logic [1:0] {
        LOAD_INIT,
        LOAD_PRG,
        LOAD_CHR,
        LOAD_DONE
    } state_t;

    state_t state;
    integer byte_index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= LOAD_INIT;
            byte_index <= 0;
            done       <= 1'b0;
            set_w      <= 1'b0;
            prg_w      <= 1'b0;
            chr_w      <= 1'b0;
            init_addr  <= '0;
            init_data  <= 8'h00;
        end
        else begin
            set_w <= 1'b0;
            prg_w <= 1'b0;
            chr_w <= 1'b0;

            case (state)
                LOAD_INIT: begin
                    // Nothing is written for a bad file; done stays low
                    if (!error) begin
                        set_w <= 1'b1;
                        state <= LOAD_PRG;
                    end
                end
                LOAD_PRG: begin
                    if (byte_index < prg_size) begin
                        init_addr  <= 15'(byte_index);
                        init_data  <= image[prg_start + byte_index];
                        prg_w      <= 1'b1;
                        byte_index <= byte_index + 1;
                    end
                    else begin
                        byte_index <= 0;
                        state      <= LOAD_CHR;
                    end
                end
                LOAD_CHR: begin
                    if (byte_index < chr_size) begin
                        init_addr  <= 15'(byte_index);
                        init_data  <= image[prg_start + prg_size + byte_index];
                        chr_w      <= 1'b1;
                        byte_index <= byte_index + 1;
                    end
                    else
                        state <= LOAD_DONE;
                end
                LOAD_DONE: done <= 1'b1;
            endcase
        end
    end

endmodule
