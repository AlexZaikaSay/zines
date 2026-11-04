// Primary OAM: 64 sprites x 4 bytes (Y, tile, attributes, X), in block RAM.
// Four 64 x 8 byte lanes, each a true dual-port RAM with registered reads:
//   CPU port ($2003/$2004): byte write and read at cpu_addr. The read data is
//     that of the previous dot; CPU accesses are at least three dots apart.
//   Sprite port: all four bytes of sprite_index, one dot later.
// Not reset: power-up content is $FF (all sprites off-screen).
module ppu_oam (
    input  logic        clk,
    input  logic        ce,
    input  logic        cpu_we,
    input  logic [7:0]  cpu_addr,       // OAMADDR
    input  logic [7:0]  cpu_wdata,
    output logic [7:0]  cpu_rdata,
    input  logic [5:0]  sprite_index,   // read address; the bytes appear on the next dot
    output logic [7:0]  sprite_y,
    output logic [7:0]  sprite_tile,
    output logic [7:0]  sprite_attr,
    output logic [7:0]  sprite_x
);

    logic [7:0] cpu_q    [0:3];
    logic [7:0] sprite_q [0:3];
    logic [1:0] cpu_lane;

    genvar b;
    generate
        for (b = 0; b < 4; b = b + 1) begin : g_lane
            logic [7:0] mem [0:63];

            initial begin
                for (int n = 0; n < 64; n = n + 1)
                    mem[n] = 8'hFF;
            end

            always_ff @(posedge clk) begin
                if (ce) begin
                    if (cpu_we && cpu_addr[1:0] == 2'(b))
                        mem[cpu_addr[7:2]] <= cpu_wdata;
                    cpu_q[b] <= mem[cpu_addr[7:2]];
                end
            end

            always_ff @(posedge clk) begin
                if (ce)
                    sprite_q[b] <= mem[sprite_index];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (ce)
            cpu_lane <= cpu_addr[1:0];
    end

    assign cpu_rdata   = cpu_q[cpu_lane];
    assign sprite_y    = sprite_q[0];
    assign sprite_tile = sprite_q[1];
    assign sprite_attr = sprite_q[2];
    assign sprite_x    = sprite_q[3];

endmodule
