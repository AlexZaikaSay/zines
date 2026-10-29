module palette_ram (
    input  logic       clk,
    input  logic [4:0] addr,
    input  logic [7:0] data_in,
    input  logic       rw,
    input  logic       cs_n,
    input  logic       oe_n,
    input  logic [4:0] pixel_addr,
    output logic [7:0] data_out,
    output logic [7:0] pixel_data_out
);

    logic [7:0] data [0:31];

    always_ff @(posedge clk) begin
        if (!cs_n && !rw)
            data[addr] <= data_in;
    end

    assign data_out = (!cs_n && !oe_n) ? data[addr] : 8'hzz;
    assign pixel_data_out = data[pixel_addr];

endmodule
