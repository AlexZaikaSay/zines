
module mux3_1
(
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [7:0] c,
    input  logic [1:0] sel,
    output logic [7:0] y
);

    assign y = (sel == 2'b00) ? a :
               (sel == 2'b01) ? b :
               (sel == 2'b10) ? c : 8'h00;

endmodule
