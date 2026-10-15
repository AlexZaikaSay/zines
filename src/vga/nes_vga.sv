// NES video -> VGA 640x480@60 through a 256x240 frame buffer.
//
// Write side (ppu_clk): stores the 6-bit palette index of every visible PPU dot,
// sampled the same way as the SDL testbench: scanlines 0-239, dots 1-256.
// Read side (vga_clk, 25.175 MHz): scans the buffer, doubling each pixel and line
// (512x480), centered with 64-pixel black borders, and maps the index to RGB444.
//
// The two sides are not frame-locked (PPU 60.10 Hz vs VGA 59.94 Hz), so a slowly
// drifting tear line can be visible; a line FIFO would underflow/overflow instead.
module nes_vga (
    // PPU side
    input  logic       ppu_clk,
    input  logic [8:0] scanline,
    input  logic [8:0] cycle,
    input  logic [7:0] pixel_palette,

    // VGA side
    input  logic       vga_clk,
    input  logic       vga_rst_n,
    output logic       hsync,
    output logic       vsync,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue
);

    // ----------------------------------------------------------------
    // Frame buffer: address = {y, x}, 64K x 6 bits (48 M9K)
    // ----------------------------------------------------------------
    logic [5:0] fb [0:65535];

    wire       pixel_visible = (scanline < 9'd240) && (cycle >= 9'd1) && (cycle <= 9'd256);
    wire [8:0] pixel_x       = cycle - 9'd1;

    always_ff @(posedge ppu_clk) begin
        if (pixel_visible)
            fb[{scanline[7:0], pixel_x[7:0]}] <= pixel_palette[5:0];
    end

    // ----------------------------------------------------------------
    // VGA 640x480@60 timing
    // ----------------------------------------------------------------
    localparam integer H_VIS   = 640;
    localparam integer H_FRONT = 16;
    localparam integer H_SYNC  = 96;
    localparam integer H_BACK  = 48;
    localparam integer H_TOTAL = H_VIS + H_FRONT + H_SYNC + H_BACK;

    localparam integer V_VIS   = 480;
    localparam integer V_FRONT = 10;
    localparam integer V_SYNC  = 2;
    localparam integer V_BACK  = 33;
    localparam integer V_TOTAL = V_VIS + V_FRONT + V_SYNC + V_BACK;

    localparam integer IMG_LEFT  = (H_VIS - 512) / 2;
    localparam integer IMG_RIGHT = IMG_LEFT + 512;

    logic [9:0] h_count;
    logic [9:0] v_count;

    always_ff @(posedge vga_clk or negedge vga_rst_n) begin
        if (!vga_rst_n) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end
        else if (h_count == 10'(H_TOTAL - 1)) begin
            h_count <= 10'd0;
            v_count <= (v_count == 10'(V_TOTAL - 1)) ? 10'd0 : v_count + 10'd1;
        end
        else begin
            h_count <= h_count + 10'd1;
        end
    end

    // ----------------------------------------------------------------
    // Pipeline: stage 0 counters/address, stage 1 RAM read, stage 2 palette + pins.
    // Sync and blanking are delayed to stay aligned with the pixel data.
    // ----------------------------------------------------------------
    wire       visible0 = (h_count < 10'(H_VIS)) && (v_count < 10'(V_VIS));
    wire       image0   = visible0 && (h_count >= 10'(IMG_LEFT)) && (h_count < 10'(IMG_RIGHT));
    wire       hs0      = (h_count >= 10'(H_VIS + H_FRONT)) && (h_count < 10'(H_VIS + H_FRONT + H_SYNC));
    wire       vs0      = (v_count >= 10'(V_VIS + V_FRONT)) && (v_count < 10'(V_VIS + V_FRONT + V_SYNC));
    wire [9:0] image_x  = h_count - 10'(IMG_LEFT);
    wire [7:0] fb_x     = image_x[8:1];
    wire [7:0] fb_y     = v_count[8:1];

    logic [5:0] fb_q;
    logic       visible1, image1, hs1, vs1;

    always_ff @(posedge vga_clk) begin
        fb_q <= fb[{fb_y, fb_x}];
    end

    always_ff @(posedge vga_clk or negedge vga_rst_n) begin
        if (!vga_rst_n) begin
            visible1 <= 1'b0;
            image1   <= 1'b0;
            hs1      <= 1'b0;
            vs1      <= 1'b0;
        end
        else begin
            visible1 <= visible0;
            image1   <= image0;
            hs1      <= hs0;
            vs1      <= vs0;
        end
    end

    // Registered outputs; 640x480@60 uses negative sync polarity.
    always_ff @(posedge vga_clk or negedge vga_rst_n) begin
        if (!vga_rst_n) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            {red, green, blue} <= 12'h000;
        end
        else begin
            hsync <= ~hs1;
            vsync <= ~vs1;
            {red, green, blue} <= (visible1 && image1) ? nes_rgb(fb_q) : 12'h000;
        end
    end

    // Same 64-color palette as emulator/utils/sdl_display.cpp, rounded to 4 bits per channel.
    function automatic [11:0] nes_rgb(input [5:0] index);
        logic [11:0] rgb;
        case (index)
            6'h00: rgb = 12'h666;  6'h01: rgb = 12'h028;  6'h02: rgb = 12'h11A;  6'h03: rgb = 12'h30A;
            6'h04: rgb = 12'h507;  6'h05: rgb = 12'h604;  6'h06: rgb = 12'h600;  6'h07: rgb = 12'h520;
            6'h08: rgb = 12'h330;  6'h09: rgb = 12'h140;  6'h0A: rgb = 12'h050;  6'h0B: rgb = 12'h050;
            6'h0C: rgb = 12'h045;  6'h0D: rgb = 12'h000;  6'h0E: rgb = 12'h000;  6'h0F: rgb = 12'h000;
            6'h10: rgb = 12'hAAA;  6'h11: rgb = 12'h16D;  6'h12: rgb = 12'h44F;  6'h13: rgb = 12'h72F;
            6'h14: rgb = 12'h92C;  6'h15: rgb = 12'hB27;  6'h16: rgb = 12'hB32;  6'h17: rgb = 12'h950;
            6'h18: rgb = 12'h660;  6'h19: rgb = 12'h380;  6'h1A: rgb = 12'h190;  6'h1B: rgb = 12'h083;
            6'h1C: rgb = 12'h078;  6'h1D: rgb = 12'h000;  6'h1E: rgb = 12'h000;  6'h1F: rgb = 12'h000;
            6'h20: rgb = 12'hFFF;  6'h21: rgb = 12'h6AF;  6'h22: rgb = 12'h98F;  6'h23: rgb = 12'hC7F;
            6'h24: rgb = 12'hE6F;  6'h25: rgb = 12'hF6C;  6'h26: rgb = 12'hF87;  6'h27: rgb = 12'hE92;
            6'h28: rgb = 12'hBB0;  6'h29: rgb = 12'h8D0;  6'h2A: rgb = 12'h5D3;  6'h2B: rgb = 12'h4D8;
            6'h2C: rgb = 12'h4CD;  6'h2D: rgb = 12'h555;  6'h2E: rgb = 12'h000;  6'h2F: rgb = 12'h000;
            6'h30: rgb = 12'hFFF;  6'h31: rgb = 12'hBDF;  6'h32: rgb = 12'hCCF;  6'h33: rgb = 12'hECF;
            6'h34: rgb = 12'hFBF;  6'h35: rgb = 12'hFCE;  6'h36: rgb = 12'hFCC;  6'h37: rgb = 12'hFDA;
            6'h38: rgb = 12'hDD9;  6'h39: rgb = 12'hCE9;  6'h3A: rgb = 12'hBEA;  6'h3B: rgb = 12'hBEC;
            6'h3C: rgb = 12'hBEE;  6'h3D: rgb = 12'hBBB;  6'h3E: rgb = 12'h000;  6'h3F: rgb = 12'h000;
            default: rgb = 12'h000;
        endcase
        return rgb;
    endfunction

    wire unused = &{1'b0, pixel_palette[7:6], scanline[8], pixel_x[8], image_x[9], v_count[9]};

endmodule
