`include "sd_card/sd_card.sv"

module tb_100_sd_card;
    localparam integer LOAD_WORDS = 128;

    logic clk;
    logic reset = 1'b0;
    logic sd_clk;
    logic sd_cmd;
    logic sd_dat0;
    logic sd_cs_n;
    logic busy;
    logic done;
    logic error;
    logic [7:0]  error_code;
    logic        rx_valid;
    logic [7:0]  rx_data;
    logic [31:0] rx_index;
    logic [7:0]  received [0:LOAD_WORDS*4-1];

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

    always #5 clk = ~clk;

    sd_card #(
        .CLK_FREQ_HZ(8_000_000),
        .INIT_SPI_HZ(400_000),
        .RUN_SPI_HZ(1_000_000),
        .LOAD_WORDS(LOAD_WORDS),
        .START_LBA(32'd7)
    ) dut (
        .clk,
        .reset,
        .sd_clk,
        .sd_cmd,
        .sd_dat0,
        .sd_cs_n,
        .sd_cd_n(1'b0),
        .busy,
        .done,
        .error,
        .error_code,
        .byte_valid(rx_valid),
        .byte_data(rx_data),
        .byte_index(rx_index)
    );

    always @(posedge clk) begin
        if (rx_valid) begin
            if (rx_index >= LOAD_WORDS * 4)
                $fatal(1, "byte_index %0d is outside the %0d-byte load", rx_index, LOAD_WORDS * 4);
            received[rx_index] <= rx_data;
        end
    end

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

    // SD command indexes in the order the controller has to send them;
    // everything after CMD58 is a CMD17 block read.
    function automatic logic [5:0] expected_command(input integer number);
        case (number)
            0: return 6'd0;
            1: return 6'd8;
            2: return 6'd55;
            3: return 6'd41;
            4: return 6'd58;
            default: return 6'd17;
        endcase
    endfunction

    task automatic respond_to_command;
        begin
            if (command[0] !== {2'b01, expected_command(command_number)})
                $fatal(1, "Command %0d: got CMD%0d (%02h), expected CMD%0d",
                       command_number, command[0][5:0], command[0],
                       expected_command(command_number));
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
    initial forever begin
        @(posedge sd_clk);
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
                    command[command_index] = command_shift;
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
    initial forever begin
        @(negedge sd_clk);
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

    initial forever begin
        @(negedge sd_cs_n);
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
        clk = 1'b0;
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
        reset = 1'b1;

        wait (done || error);

        if (error) begin
            $fatal(1, "SD controller entered error state, code %02h", error_code);
        end
        if (busy)
            $fatal(1, "SD controller still busy after done");
        if ({received[3], received[2], received[1], received[0]} !== 32'h03020100)
            $fatal(1, "Unexpected first word: %02h%02h%02h%02h",
                   received[3], received[2], received[1], received[0]);
        if ({received[511], received[510], received[509], received[508]} !== 32'hFFFEFDFC)
            $fatal(1, "Unexpected last word: %02h%02h%02h%02h",
                   received[511], received[510], received[509], received[508]);

        $display("SD-card read test passed");
        $finish;
    end

    initial begin
        repeat (250_000) @(posedge clk);
        $fatal(1, "Timed out waiting for SD-card read");
    end
endmodule
