// Simulation model of an SDHC card in SPI mode, backed by an image file.
// Sector reads and writes go straight to SD_FILE (opened "r+b"), so writes
// persist after the simulation.
//
// Commands: CMD0, CMD8, CMD55/ACMD41, CMD58 (CCS = 1), CMD16, CMD17, CMD24.
// Anything else answers R1 "illegal command".
//
// The model watches sd_clk in the clk domain, so the master's SPI half
// period must be at least 2 clk cycles (sd_card RUN_DIV >= 2).
// Behavioral model: blocking assignments in the clocked process are intended.
/* verilator lint_off BLKSEQ */
/* verilator lint_off UNUSEDSIGNAL */
module sim_sd_card #(
    parameter string  SD_FILE = "sd.img",
    // ACMD41 calls answered "still idle" before the card is ready
    parameter integer ACMD41_BUSY = 1,
    // Busy bytes (00) after a write before the card is ready again
    parameter integer WRITE_BUSY  = 4,
    // Print every command
    parameter bit     VERBOSE     = 0
)(
    input  logic clk,
    input  logic rst_n,
    input  logic sd_clk,
    input  logic sd_cmd,     // MOSI
    input  logic sd_cs_n,
    output logic sd_dat0     // MISO
);

    // Opened on first access, so a testbench can create the image at time 0
    integer fd = 0;
    logic   open_failed = 1'b0;

    function automatic logic file_ready();
        if (fd == 0 && !open_failed) begin
            fd = $fopen(SD_FILE, "r+b");
            if (fd == 0) begin
                open_failed = 1'b1;
                $display("sim_sd_card: cannot open %s, card reads as empty", SD_FILE);
            end
        end
        return fd != 0;
    endfunction

    // ---------------- Response queue ----------------
    logic [7:0] queue [0:1023];
    integer     q_head, q_tail;
    integer     busy_left;

    task automatic push(input logic [7:0] b);
        queue[q_tail[9:0]] = b;
        q_tail = q_tail + 1;
    endtask

    function automatic logic [7:0] next_tx();
        logic [7:0] b;
        if (q_head != q_tail) begin
            b = queue[q_head[9:0]];
            q_head = q_head + 1;
        end
        else if (busy_left > 0) begin
            b = 8'h00;
            busy_left = busy_left - 1;
        end
        else
            b = 8'hFF;
        return b;
    endfunction

    // ---------------- Card state ----------------
    typedef enum { M_CMD, M_WRITE_TOKEN, M_WRITE_DATA } mode_t;

    mode_t      mode;
    logic [7:0] cmd [0:5];
    integer     cmd_count;
    logic       idle;
    logic       app_cmd;
    integer     acmd41_count;
    logic [31:0] write_lba;
    logic [7:0] sector [0:511];
    integer     data_count;

    task automatic read_sector(input logic [31:0] lba);
        integer n;
        for (int i = 0; i < 512; i++)
            sector[i] = 8'h00;
        if (file_ready()) begin
            n = $fseek(fd, lba * 512, 0);
            n = $fread(sector, fd, 0, 512);
        end
    endtask

    task automatic write_sector(input logic [31:0] lba);
        integer n;
        if (file_ready()) begin
            n = $fseek(fd, lba * 512, 0);
            for (int i = 0; i < 512; i++)
                $fwrite(fd, "%c", sector[i]);
            $fflush(fd);
        end
    endtask

    function automatic logic [7:0] r1();
        return {7'b0, idle};
    endfunction

    task automatic execute();
        logic [5:0]  index;
        logic [31:0] arg;
        index = cmd[0][5:0];
        arg   = {cmd[1], cmd[2], cmd[3], cmd[4]};

        if (VERBOSE)
            $display("sim_sd_card: %sCMD%0d arg=%08h", app_cmd ? "A" : "", index, arg);

        push(8'hFF);                        // N_CR: one byte before R1

        if (app_cmd && index == 6'd41) begin
            acmd41_count = acmd41_count + 1;
            if (acmd41_count > ACMD41_BUSY)
                idle = 1'b0;
            push(r1());
        end
        else case (index)
            6'd0: begin
                idle = 1'b1;
                acmd41_count = 0;
                push(8'h01);
            end
            6'd8: begin                     // R7: echo voltage + check pattern
                push(r1());
                push(8'h00);
                push(8'h00);
                push({4'h0, arg[11:8]});
                push(arg[7:0]);
            end
            6'd55: push(r1());
            6'd58: begin                    // R3: OCR, powered up + CCS
                push(r1());
                push(8'hC0);
                push(8'hFF);
                push(8'h80);
                push(8'h00);
            end
            6'd16: push(r1());
            6'd17: begin                    // block address (SDHC)
                read_sector(arg);
                push(r1());
                push(8'hFF);
                push(8'hFE);
                for (int i = 0; i < 512; i++)
                    push(sector[i]);
                push(8'hFF);                // CRC16, not checked
                push(8'hFF);
            end
            6'd24: begin
                write_lba = arg;
                push(r1());
                mode = M_WRITE_TOKEN;
            end
            default: push(r1() | 8'h04);    // illegal command
        endcase

        app_cmd = (index == 6'd55) && !app_cmd;
    endtask

    // Handle one byte from the host
    task automatic receive(input logic [7:0] b);
        case (mode)
            M_CMD: begin
                // A command starts with 01xx_xxxx; FF filler is ignored
                if (cmd_count != 0 || b[7:6] == 2'b01) begin
                    cmd[cmd_count] = b;
                    cmd_count = cmd_count + 1;
                    if (cmd_count == 6) begin
                        cmd_count = 0;
                        execute();
                    end
                end
            end
            M_WRITE_TOKEN: begin
                if (b == 8'hFE) begin
                    data_count = 0;
                    mode = M_WRITE_DATA;
                end
            end
            M_WRITE_DATA: begin
                if (data_count < 512)
                    sector[data_count] = b;
                data_count = data_count + 1;
                if (data_count == 514) begin // 512 data + CRC16
                    write_sector(write_lba);
                    push(8'h05);            // data accepted
                    busy_left = WRITE_BUSY;
                    mode = M_CMD;
                end
            end
        endcase
    endtask

    // ---------------- SPI slave, mode 0 ----------------
    logic       sclk_q;
    logic [7:0] rx_shift;
    logic [7:0] tx_shift;
    integer     bit_count;
    logic       loaded;     // tx_shift just reloaded: skip the next shift

    assign sd_dat0 = sd_cs_n ? 1'b1 : tx_shift[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_q       = 1'b0;
            rx_shift     = 8'h00;
            tx_shift     = 8'hFF;
            bit_count    = 0;
            loaded       = 1'b0;
            q_head       = 0;
            q_tail       = 0;
            busy_left    = 0;
            mode         = M_CMD;
            cmd_count    = 0;
            idle         = 1'b1;
            app_cmd      = 1'b0;
            acmd41_count = 0;
        end
        else begin
            if (sd_cs_n) begin
                bit_count = 0;
                loaded    = 1'b0;
                tx_shift  = 8'hFF;
            end
            else if (sd_clk && !sclk_q) begin
                // Rising edge: sample MOSI
                rx_shift  = {rx_shift[6:0], sd_cmd};
                bit_count = bit_count + 1;
                if (bit_count == 8) begin
                    bit_count = 0;
                    receive(rx_shift);
                    tx_shift = next_tx();
                    loaded   = 1'b1;
                end
            end
            else if (!sd_clk && sclk_q) begin
                // Falling edge: next bit out
                if (loaded)
                    loaded = 1'b0;
                else
                    tx_shift = {tx_shift[6:0], 1'b1};
            end
            sclk_q = sd_clk;
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on BLKSEQ */
