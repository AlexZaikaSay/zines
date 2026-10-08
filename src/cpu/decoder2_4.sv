
module decoder2_4 (
    input logic [1:0] a,
    input logic en_n,
    output logic [3:0] y
);

    assign y = en_n ? 4'b0000 : (4'b0001 << a);

endmodule
