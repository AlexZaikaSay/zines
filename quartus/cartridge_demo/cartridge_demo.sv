module cartridge_demo (
    input  logic       CLOCK_50,
    input  logic       RESET_N,

    output logic       SD_CLK,
    output logic       SD_CMD,
    input  logic       SD_DAT0,
    output logic       SD_CS_N,
    input  logic       SD_CD,

    output logic [7:0] SMG_Data,
    output logic [2:0] Scan_Sig,
    output logic       LEDR,
    output logic       LED2
);
    logic       loaded;
    logic       error;
    logic [7:0] error_code;
    logic [7:0] cpu_data_out;
    logic [7:0] ppu_data_out;

    logic [31:0] scan_counter;
    logic [1:0]  scan_digit;
    logic [7:0]  displayed_byte;
    logic [3:0]  displayed_nibble;

    cartridge cartridge_inst (
        .clk(CLOCK_50),
        .reset(RESET_N),
        .sd_clk(SD_CLK),
        .sd_cmd(SD_CMD),
        .sd_dat0(SD_DAT0),
        .sd_cs_n(SD_CS_N),
        .sd_cd_n(SD_CD),
        // First PRG-ROM byte is at $8000.
        .cpu_addr(16'h8000),
        .cpu_data_in(8'h00),
        .cpu_data_out,
        .cpu_rw(1'b1),
        .cpu_ce(1'b1),
        .ppu_addr(14'h0000),
        .ppu_rd(1'b1),
        .ppu_wr(1'b0),
        .ppu_data_in(8'h00),
        .ppu_data_out,
        .ciram_a10(),
        .ciram_ce(),
        .loaded,
        .error,
        .error_code
    );

    // Show the error code until the ROM is loaded, then the first PRG byte.
    assign displayed_byte = loaded ? ppu_data_out : error_code;
    assign LEDR = loaded;
    assign LED2 = SD_CD;

    always_ff @(posedge CLOCK_50 or negedge RESET_N) begin
        if (!RESET_N) begin
            scan_counter <= 32'd0;
            scan_digit <= 2'd0;
        end
        else if (scan_counter == 32'd49_999) begin
            scan_counter <= 32'd0;
            if (scan_digit == 2'd2)
                scan_digit <= 2'd0;
            else
                scan_digit <= scan_digit + 1'b1;
        end
        else begin
            scan_counter <= scan_counter + 1'b1;
        end
    end

    always_comb begin
        case (scan_digit)
            2'd0: begin
                Scan_Sig = 3'b100;
                displayed_nibble = 4'hF;
            end
            2'd1: begin
                Scan_Sig = 3'b010;
                displayed_nibble = displayed_byte[7:4];
            end
            default: begin
                Scan_Sig = 3'b001;
                displayed_nibble = displayed_byte[3:0];
            end
        endcase

        case (displayed_nibble)
            4'h0: SMG_Data = 8'b1100_0000;
            4'h1: SMG_Data = 8'b1111_1001;
            4'h2: SMG_Data = 8'b1010_0100;
            4'h3: SMG_Data = 8'b1011_0000;
            4'h4: SMG_Data = 8'b1001_1001;
            4'h5: SMG_Data = 8'b1001_0010;
            4'h6: SMG_Data = 8'b1000_0010;
            4'h7: SMG_Data = 8'b1111_1000;
            4'h8: SMG_Data = 8'b1000_0000;
            4'h9: SMG_Data = 8'b1001_0000;
            4'hA: SMG_Data = 8'b1000_1000;
            4'hB: SMG_Data = 8'b1000_0011;
            4'hC: SMG_Data = 8'b1100_0110;
            4'hD: SMG_Data = 8'b1010_0001;
            4'hE: SMG_Data = 8'b1000_0110;
            4'hF: SMG_Data = 8'b1000_1110;
            default: SMG_Data = 8'b1111_1111;
        endcase
    end
endmodule
