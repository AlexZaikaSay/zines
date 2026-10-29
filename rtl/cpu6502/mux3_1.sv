
module mux3_1 
# (
    parameter WIDTH = 8
)
(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [WIDTH-1:0] c,
    input  logic [1:0] sel,
    output logic [WIDTH-1:0] y
);

    assign y = (sel == 0) ? a :
               (sel == 1) ? b :
               (sel == 2) ? c : {WIDTH{1'b0}};

endmodule
