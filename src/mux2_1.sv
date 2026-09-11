
module mux2_1
(
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic       sel,
    output logic [7:0] y
);

    assign y = sel ? b : a;

endmodule
