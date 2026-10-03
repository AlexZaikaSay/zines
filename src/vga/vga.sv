

module vga #
(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer RUN_VGA_HZ  = 25_000_000
)(
    input  logic       clk,
    input  logic       reset,
    output logic       hsync,
    output logic       vsync,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
);

    // ================================================================
    // VGA clock divider
    // ================================================================

    localparam integer VGA_DIV = (CLK_FREQ_HZ / RUN_VGA_HZ) - 1;

    
    localparam integer VGA_H_VIS = 640;
    localparam integer VGA_H_FRONT_PORCH = 16;
    localparam integer VGA_H_SYNC = 96;
    localparam integer VGA_H_BACK_PORCH = 48;
    localparam integer VGA_H_TOTAL = VGA_H_VIS + VGA_H_FRONT_PORCH + VGA_H_SYNC + VGA_H_BACK_PORCH;

    localparam integer VGA_V_VIS = 480;
    localparam integer VGA_V_FRONT_PORCH = 11;
    localparam integer VGA_V_SYNC = 2;
    localparam integer VGA_V_BACK_PORCH = 31;
    localparam integer VGA_V_TOTAL = VGA_V_VIS + VGA_V_FRONT_PORCH + VGA_V_SYNC + VGA_V_BACK_PORCH;

    logic               vga_active;

    logic [31:0]        div_cnt;
    logic [31:0]        h_counter;
    logic [31:0]        v_counter;

    logic               h_visible;
    logic               v_visible;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            div_cnt <= 0;
            vga_active <= 0;
        end else if (div_cnt >= VGA_DIV) begin
            div_cnt <= 0;
            vga_active <= 1;
        end else begin
            div_cnt <= div_cnt + 1;
            vga_active <= 0;
        end
    end

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            hsync <= 1;
            vsync <= 1;
            h_counter <= 0;
            v_counter <= 0;
            h_visible <= 1;
            v_visible <= 1;
        end else begin
            if (vga_active) begin
                h_counter <= h_counter + 1;
                if (h_counter == VGA_H_VIS)
                    h_visible <= 0;
                else if (h_counter == VGA_H_VIS + VGA_H_FRONT_PORCH)
                    hsync <= 0;
                else if (h_counter == VGA_H_VIS + VGA_H_FRONT_PORCH + VGA_H_SYNC)
                    hsync <= 1;
                else  if (h_counter == VGA_H_TOTAL) begin
                    h_visible <= 1;
                    h_counter <= 0;
                    v_counter <= v_counter + 1;
                    if (v_counter == VGA_V_VIS)
                        v_visible <= 0;
                    else if (v_counter == VGA_V_VIS + VGA_V_FRONT_PORCH)
                        vsync <= 0;
                    else if (v_counter == VGA_V_VIS + VGA_V_FRONT_PORCH + VGA_V_SYNC)
                        vsync <= 1;
                    else if (v_counter == VGA_V_TOTAL) begin
                        v_visible <= 1;
                        v_counter <= 0;
                    end
                end
            end
        end
    end

endmodule

