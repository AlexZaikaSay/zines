
module adder (
    input  [7:0] a,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // Concatenate cout and sum to capture the 9-bit result of the addition
    assign {cout, sum} = a + {8'b0, cin};

endmodule
