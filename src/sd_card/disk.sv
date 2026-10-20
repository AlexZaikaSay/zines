
module disk #
(
    parameter string SD_FILE = "sd.img"
)
(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [8:0] addr,
    input  logic       rw,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic       active,
    output logic [7:0] status,
    output logic [7:0] errcode,
    output logic [31:0] lba
);

    // Disk implementation here
    assign active = 1'b0;
    assign status = 8'h00;
    assign errcode = 8'h00;
    assign lba = 32'h00000000;

endmodule
