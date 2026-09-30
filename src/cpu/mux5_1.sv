
module mux5_1
(
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [7:0] c,
    input  logic [7:0] d,
    input  logic [7:0] e,
    input  logic [2:0] sel,
    output logic [7:0] y
);

    assign y = (sel == 0) ? a :
               (sel == 1) ? b :
               (sel == 2) ? c :
               (sel == 3) ? d :
               (sel == 4) ? e : 8'h00;

endmodule
