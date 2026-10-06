
`include "mux3_1.sv"

module int_control(
    input  logic [1:0]  sel,
    output logic [15:0] irq_addr_h,
    output logic [15:0] irq_addr_l
);
    mux3_1 #(
        .WIDTH(16)
    ) h_mux3_1 (
        .a(16'hFFFB),
        .b(16'hFFFD),
        .c(16'hFFFF),
        .sel(sel),
        .y(irq_addr_h)
    );

    mux3_1 #(
        .WIDTH(16)
    ) l_mux3_1 (
        .a(16'hFFFA),
        .b(16'hFFFC),
        .c(16'hFFFE),
        .sel(sel),
        .y(irq_addr_l)
    );
    
endmodule
