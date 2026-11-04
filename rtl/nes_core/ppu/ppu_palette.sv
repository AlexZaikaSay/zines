// Palette RAM: 32 bytes at $3F00-$3FFF of the PPU bus, inside the PPU (it never
// reaches the external pins). $3F10/14/18/1C mirror $3F00/04/08/0C.
// Bus port: written on a bus write dot, read combinationally. Pixel port: colour
// of the palette index chosen by the mixer.
module ppu_palette (
    input  logic        clk,
    input  logic        ce,
    input  logic [13:0] addr,           // PPU bus address
    input  logic        we,             // bus write dot (decoded with sel here)
    input  logic [7:0]  wdata,
    output logic        sel,            // addr is in $3F00-$3FFF
    output logic [7:0]  rdata,
    input  logic [4:0]  pixel_index,
    output logic [7:0]  pixel_color
);

    logic [7:0] data [0:31];

    function automatic [4:0] mirror(input [4:0] a);
        mirror = (a[1:0] == 2'b00) ? {1'b0, a[3:0]} : a;
    endfunction

    assign sel = addr[13:8] == 6'h3F;

    always_ff @(posedge clk) begin
        if (ce && we && sel)
            data[mirror(addr[4:0])] <= wdata;
    end

    assign rdata       = data[mirror(addr[4:0])];
    assign pixel_color = data[mirror(pixel_index)];

    wire unused = &{1'b0, addr[7:5]};

endmodule
