
module int_control(
    output logic [15:0] irq_addr_h,
    output logic [15:0] irq_addr_l
);
    assign irq_addr_h = 16'hFFFF;
    assign irq_addr_l = 16'hFFFE;
    
endmodule
