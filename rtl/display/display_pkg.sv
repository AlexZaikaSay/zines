// Display constants and the NES palette, shared by the display modules.
/* verilator lint_off UNUSEDPARAM */   // each user needs only some constants
package display_pkg;

    // 640x480@60, 25.2 MHz pixel clock, negative sync polarity
    localparam integer H_VIS   = 640;
    localparam integer H_FRONT = 16;
    localparam integer H_SYNC  = 96;
    localparam integer H_BACK  = 48;
    localparam integer H_TOTAL = H_VIS + H_FRONT + H_SYNC + H_BACK;   // 800

    localparam integer V_VIS   = 480;
    localparam integer V_FRONT = 10;
    localparam integer V_SYNC  = 2;
    localparam integer V_BACK  = 33;
    localparam integer V_TOTAL = V_VIS + V_FRONT + V_SYNC + V_BACK;   // 525

    // NES picture: 256x240 doubled to 512x480, centered horizontally
    localparam integer IMG_LEFT  = (H_VIS - 512) / 2;
    localparam integer IMG_RIGHT = IMG_LEFT + 512;

    // Same 64-color palette as sim/top/utils/sdl_display.cpp, rounded to 4 bits per channel.
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

endpackage
/* verilator lint_on UNUSEDPARAM */
