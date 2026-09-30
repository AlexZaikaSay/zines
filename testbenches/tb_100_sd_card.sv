`include "sd_card.sv"

module tb_100_sd_card;
    localparam integer RAM_WORDS = 128;

    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic sd_clk;
    logic sd_cmd;
    logic sd_dat0;
    logic sd_cs_n;
    logic busy;
    logic done;
    logic error;
    logic [RAM_WORDS-1:0][31:0] ram;

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

    always #5 clk = ~clk;

    sd_card #(
        .CLK_FREQ_HZ(8_000_000),
        .INIT_SPI_HZ(400_000),
        .RUN_SPI_HZ(1_000_000),
        .RAM_WORDS(RAM_WORDS),
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
        .ram
    );

    task automatic queue_byte(input logic [7:0] value);
        begin
            response_queue[response_tail] = value;
            response_tail = response_tail + 1;
        end
    endtask

    task automatic queue_sector;
        begin
            queue_byte(8'h00);
            for (byte_index = 0; byte_index < 300; byte_index = byte_index + 1)
                queue_byte(8'hFF);
            queue_byte(8'hFE);
            for (byte_index = 0; byte_index < 512; byte_index = byte_index + 1)
                queue_byte(byte_index[7:0]);
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
                5: queue_sector;      // CMD17: one 512-byte block
                default: begin
                    $fatal(1, "Unexpected SD command number %0d", command_number);
                end
            endcase
            command_number = command_number + 1;
        end
    endtask

    // Capture command bytes on SPI rising edges. The response starts on the
    // following falling edge, matching SPI mode 0.
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

    // Present the next response bit before each SPI rising edge.
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
        $dumpfile("tb_100_sd_card.vcd");
        $dumpvars(0, tb_100_sd_card);
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

        if (error) begin
            $fatal(1, "SD controller entered error state");
        end
        if (busy)
            $fatal(1, "SD controller still busy after done");
        if (ram[0] !== 32'h03020100)
            $fatal(1, "Unexpected first RAM word: %08h", ram[0]);
        if (ram[127] !== 32'hFFFEFDFC)
            $fatal(1, "Unexpected last RAM word: %08h", ram[127]);

        $display("SD-card read test passed");
        $finish;
    end

    initial begin
        repeat (250_000) @(posedge clk);
        $fatal(1, "Timed out waiting for SD-card read");
    end
endmodule
