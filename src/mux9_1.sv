
module mux9_1
(
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [7:0] c,
    input  logic [7:0] d,
    input  logic [7:0] e,
    input  logic [7:0] f,
    input  logic [7:0] g,
    input  logic [7:0] h,
    input  logic [7:0] i,
    input  logic [3:0] sel,
    output logic [7:0] y
);

    assign y = (sel == 0) ? a :
               (sel == 1) ? b :
               (sel == 2) ? c :
               (sel == 3) ? d :
               (sel == 4) ? e :
               (sel == 5) ? f :
               (sel == 6) ? g :
               (sel == 7) ? h :
               (sel == 8) ? i :
               8'h00;

endmodule
