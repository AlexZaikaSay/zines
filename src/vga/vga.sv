

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
    localparam integer VGA_V_FRONT_PORCH = 10;
    localparam integer VGA_V_SYNC = 2;
    localparam integer VGA_V_BACK_PORCH = 33;
    localparam integer VGA_V_TOTAL = VGA_V_VIS + VGA_V_FRONT_PORCH + VGA_V_SYNC + VGA_V_BACK_PORCH;

    logic               vga_active;

    logic [31:0]        div_cnt;
    logic [31:0]        h_counter;
    logic [31:0]        v_counter;


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

    wire eol = (h_counter == VGA_H_TOTAL - 1);
    wire eof = (v_counter == VGA_V_TOTAL - 1);
    
    wire h_visible = (h_counter < VGA_H_VIS);
    wire v_visible = (v_counter < VGA_V_VIS);
    wire visible = h_visible && v_visible;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            h_counter <= 0;
            v_counter <= 0;
 
        end else begin
            if (vga_active) begin
                h_counter <= h_counter + 1;
                if (eol) begin
                    h_counter <= 0;
                    v_counter <= v_counter + 1;
                    if (eof) begin
                        v_counter <= 0;
                    end
                end
            end
        end
    end

    // Test pattern: 8 vertical color bars across the visible area.
    wire [2:0] bar = 3'(h_counter / (VGA_H_VIS / 8));

    wire h_sync_pulse = (h_counter >= VGA_H_VIS + VGA_H_FRONT_PORCH) && (h_counter < VGA_H_VIS + VGA_H_FRONT_PORCH + VGA_H_SYNC);
    wire v_sync_pulse = (v_counter >= VGA_V_VIS + VGA_V_FRONT_PORCH) && (v_counter < VGA_V_VIS + VGA_V_FRONT_PORCH + VGA_V_SYNC);

    // Registered outputs: no combinational glitches on the pins.
    // 640x480@60 uses negative sync polarity.
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            red   <= 4'h0;
            green <= 4'h0;
            blue  <= 4'h0;
        end else begin
            hsync <= ~h_sync_pulse;
            vsync <= ~v_sync_pulse;
            red   <= visible ? {4{bar[0]}} : 4'h0;
            green <= visible ? {4{bar[1]}} : 4'h0;
            blue  <= visible ? {4{bar[2]}} : 4'h0;
        end
    end

endmodule

