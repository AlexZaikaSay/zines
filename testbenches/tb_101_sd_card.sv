`include "sd_card.sv"

module tb_101_sd_card;
    localparam integer ASSET_BYTES = 40976;
    localparam string  ASSET_FILE = "../assets/SMB.nes";
    localparam integer SECTOR_BYTES = 512;
    localparam integer IMAGE_SECTORS = (ASSET_BYTES + SECTOR_BYTES - 1) / SECTOR_BYTES;
    localparam integer LOAD_WORDS = IMAGE_SECTORS * 128;

    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic sd_clk;
    logic sd_cmd;
    logic sd_dat0;
    logic sd_cs_n;
    logic busy;
    logic done;
    logic error;
    logic        rx_valid;
    logic [7:0]  rx_data;
    logic [31:0] rx_index;
    logic [7:0]  received [0:LOAD_WORDS*4-1];

    logic [7:0] asset_image [0:ASSET_BYTES-1];
    logic [7:0] command [0:5];
    logic [7:0] command_shift;
    logic [7:0] response_queue [0:1023];
    integer command_index;
    integer command_bit;
    integer response_head;
    integer response_tail;
    integer response_bit;
    logic collecting_command;
    integer command_number;
    integer byte_index;
    integer word_index;
    integer asset_file;
    integer bytes_read;

    always #5 clk = ~clk;

    sd_card #(
        .CLK_FREQ_HZ(8_000_000),
        .INIT_SPI_HZ(400_000),
        .RUN_SPI_HZ(1_000_000),
        .LOAD_WORDS(LOAD_WORDS),
        .START_LBA(32'd7)
    ) dut (
        .clk,
        .reset_n,
        .sd_clk,
        .sd_cmd,
        .sd_dat0,
        .sd_cs_n,
        .sd_cd_n(1'b0),
        .busy,
        .done,
        .error,
        .byte_valid(rx_valid),
        .byte_data(rx_data),
        .byte_index(rx_index)
    );

    always @(posedge clk) begin
        if (rx_valid)
            received[rx_index] <= rx_data;
    end

    task automatic queue_byte(input logic [7:0] value);
        begin
            response_queue[response_tail] = value;
            response_tail = response_tail + 1;
        end
    endtask

    task automatic queue_sector(input integer sector_number);
        integer image_index;
        begin
            queue_byte(8'h00);
            queue_byte(8'hFE);
            for (byte_index = 0; byte_index < SECTOR_BYTES; byte_index = byte_index + 1) begin
                image_index = sector_number * SECTOR_BYTES + byte_index;
                if (image_index < ASSET_BYTES)
                    queue_byte(asset_image[image_index]);
                else
                    queue_byte(8'h00);
            end
            queue_byte(8'h00);
            queue_byte(8'h00);
        end
    endtask

    task automatic respond_to_command;
        begin
            case (command_number)
                0: queue_byte(8'h01); // CMD0: idle
                1: begin              // CMD8: SD v2, 2.7-3.6 V
                    queue_byte(8'h01);
                    queue_byte(8'h00);
                    queue_byte(8'h00);
                    queue_byte(8'h01);
                    queue_byte(8'hAA);
                end
                2: queue_byte(8'h01); // CMD55: application command prefix
                3: queue_byte(8'h00); // ACMD41: ready
                4: begin              // CMD58: CCS set, SDHC
                    queue_byte(8'h00);
                    queue_byte(8'h40);
                    queue_byte(8'h00);
                    queue_byte(8'h00);
                    queue_byte(8'h00);
                end
                default: queue_sector(command_number - 5); // CMD17
            endcase
            command_number = command_number + 1;
        end
    endtask

    always @(posedge sd_clk) begin
        if (!sd_cs_n) begin
            if (!collecting_command && (sd_cmd == 1'b0)) begin
                collecting_command = 1'b1;
                command_index = 0;
                command_bit = 0;
                command_shift = 0;
            end

            if (collecting_command) begin
                command_shift = {command_shift[6:0], sd_cmd};
                if (command_bit == 7) begin
                    command[command_index] = {command_shift[6:0], sd_cmd};
                    if (command_index == 5) begin
                        respond_to_command();
                        collecting_command = 1'b0;
                        command_index = 0;
                        command_bit = 0;
                    end
                    else begin
                        command_index = command_index + 1;
                        command_bit = 0;
                    end
                end
                else begin
                    command_bit = command_bit + 1;
                end
            end
        end
    end

    always @(negedge sd_clk) begin
        if (!sd_cs_n) begin
            if (response_head < response_tail) begin
                sd_dat0 = response_queue[response_head][7 - response_bit];
                if (response_bit == 7) begin
                    response_bit = 0;
                    response_head = response_head + 1;
                end
                else begin
                    response_bit = response_bit + 1;
                end
            end
            else begin
                sd_dat0 = 1'b1;
            end
        end
    end

    always @(negedge sd_cs_n) begin
        command_index = 0;
        command_bit = 0;
        command_shift = 0;
        collecting_command = 1'b0;
        response_head = 0;
        response_tail = 0;
        response_bit = 0;
        sd_dat0 = 1'b1;
    end

    initial begin
        $dumpfile("tb_101_sd_card.vcd");
        $dumpvars(0, tb_101_sd_card);
        asset_file = $fopen(ASSET_FILE, "rb");
        if (asset_file == 0)
            $fatal(1, "Unable to open %s", ASSET_FILE);
        bytes_read = $fread(asset_image, asset_file);
        $fclose(asset_file);
        if (bytes_read != ASSET_BYTES)
            $fatal(1, "Expected %0d asset bytes, read %0d", ASSET_BYTES, bytes_read);

        command_index = 0;
        command_bit = 0;
        command_shift = 0;
        collecting_command = 1'b0;
        response_head = 0;
        response_tail = 0;
        response_bit = 0;
        command_number = 0;
        sd_dat0 = 1'b1;

        repeat (4) @(posedge clk);
        reset_n = 1'b1;

        wait (done || error);

        if (error)
            $fatal(1, "SD controller entered error state");
        if (busy)
            $fatal(1, "SD controller still busy after done");

        for (word_index = 0; word_index < ASSET_BYTES; word_index = word_index + 1) begin
            if (received[word_index] !== asset_image[word_index])
                $fatal(1, "Mismatch at byte %0d: %02h", word_index, received[word_index]);
        end

        if (received[ASSET_BYTES] !== 8'h00)
            $fatal(1, "Expected zero padding after asset: %02h", received[ASSET_BYTES]);

        $display("%s SD-card load test passed (%0d bytes)", ASSET_FILE, ASSET_BYTES);
        $finish;
    end

    initial begin
        repeat (10_000_000) @(posedge clk);
        $fatal(1, "Timed out waiting for %s SD-card load", ASSET_FILE);
    end
endmodule
