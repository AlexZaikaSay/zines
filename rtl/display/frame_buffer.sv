// NES frame buffer: 256x240 palette indices, address {y, x}, 64K x 6 (48 M9K).
// Two clocks: written from the PPU side, read from the display side with a
// registered read (data one rclk after the address). Memory only, so it maps to BRAM.
module frame_buffer (
    input  logic       wclk,
    input  logic       we,
    input  logic [7:0] wx,
    input  logic [7:0] wy,
    input  logic [5:0] wdata,

    input  logic       rclk,
    input  logic [7:0] rx,
    input  logic [7:0] ry,
    output logic [5:0] rdata
);

    logic [5:0] mem [0:65535];

    always_ff @(posedge wclk) begin
        if (we)
            mem[{wy, wx}] <= wdata;
    end

    always_ff @(posedge rclk) begin
        rdata <= mem[{ry, rx}];
    end

endmodule
