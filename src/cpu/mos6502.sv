
`include "alu.sv"
`include "mux5_1.sv"
`include "mux9_1.sv"
`include "ff.sv"
`include "main_fsm.sv"
`include "int_control.sv"


module mos6502 #(
    parameter PC_START = 16'h0000
) (
    input logic rst,
    input logic clk,
    input logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic [15:0] addr,
    output logic we,
    output logic undef
);
    logic [7:0] pc_h;
    logic [7:0] pc_l;
    logic [7:0] high_byte;
    logic [7:0] low_byte;
    logic [7:0] temp;
    logic [7:0] flags;
    logic [7:0] alu_result;
    logic [7:0] alu_a;
    logic [7:0] alu_b;
    logic [7:0] a;
    logic [7:0] x;
    logic [7:0] y;
    logic [7:0] s;

    logic [15:0] irq_addr_h;
    logic [15:0] irq_addr_l;


    logic c;
    logic z;
    logic v;
    logic n;

    logic c_in;

    logic w_a;
    logic w_x;
    logic w_y;
    logic w_s;

    logic [2:0] src_addr_h;
    logic [2:0] src_addr_l;
    logic [3:0] src_alu_a;
    logic [2:0] src_alu_b;
    logic [1:0] src_c_in;
    logic [2:0] src_data_out;

    logic [3:0] alu_op;

    int_control int_control_inst(
        .sel(2'b10),
        .irq_addr_h(irq_addr_h),
        .irq_addr_l(irq_addr_l)
    );

    mux5_1 addr_h_mux5_1(
        .a(pc_h),
        .b(high_byte),
        .c(8'h01),
        .d(irq_addr_h[15:8]), 
        .e(irq_addr_l[15:8]),
        .sel(src_addr_h), 
        .y(addr[15:8])
    );

    mux5_1 addr_l_mux5_1(
        .a(pc_l),
        .b(low_byte),
        .c(s),
        .d(irq_addr_h[7:0]),
        .e(irq_addr_l[7:0]),
        .sel(src_addr_l),
        .y(addr[7:0])
    );

    ff a_ff (
        .clk(clk),
        .rst(rst),
        .d(alu_result),
        .en(w_a),
        .q(a)
    );

    ff x_ff (
        .clk(clk),
        .rst(rst),
        .d(alu_result),
        .en(w_x),
        .q(x)
    );


    ff y_ff (
        .clk(clk),
        .rst(rst),
        .d(alu_result),
        .en(w_y),
        .q(y)
    );

    ff s_ff (
        .clk(clk),
        .rst(rst),
        .d(alu_result),
        .en(w_s),
        .q(s)
    );

    mux3_1 #(.WIDTH(1)) carry_in_mux3_1(
        .a(flags[0]), // TODO: make constants
        .b(1'b0),
        .c(1'b1),
        .sel(src_c_in),
        .y(c_in)
    );

    main_fsm #
    (
        .PC_START(PC_START)
    )
    fsm 
    (
        .clk(clk),
        .rst(rst),
        .imm(data_in),
        .alu_result(alu_result),
        .c(c),
        .v(v),
        .z(z),
        .n(n),
        .w_a(w_a),
        .w_x(w_x),
        .w_y(w_y),
        .w_s(w_s),
        .w_mem(we),
        .src_c_in(src_c_in),
        .src_data_out(src_data_out),
        .src_addr_h(src_addr_h),
        .src_addr_l(src_addr_l),
        .src_alu_a(src_alu_a),
        .src_alu_b(src_alu_b),
        .alu_op(alu_op),
        .temp(temp),
        .pc_h(pc_h),
        .pc_l(pc_l),
        .high_byte(high_byte),
        .low_byte(low_byte),
        .flags(flags),
        .undef(undef)
    );

    mux9_1 src_alu_a_mux9_1(
        .a(a),
        .b(x),
        .c(y),
        .d(s),
        .e(pc_l),
        .f(pc_h),
        .g(low_byte),
        .h(high_byte),
        .i(temp),
        .sel(src_alu_a),
        .y(alu_a)
    );

    mux5_1 src_alu_b_mux5_1(
        .a(data_in),
        .b(low_byte),
        .c(8'h00),
        .d(8'h01),
        .e(temp),
        .sel(src_alu_b),
        .y(alu_b)
    );

    alu alu_device (
        .alu_op(alu_op),
        .a_in(alu_a),
        .b_in(alu_b),
        .c_in(c_in),
        .result(alu_result),
        .v(v),
        .n(n),
        .z(z),
        .c(c)
    );

    mux5_1 src_data_out_mux5_1(
        .a(alu_result),
        .b(a),
        .c(flags),
        .d(pc_h),
        .e(pc_l),
        .sel(src_data_out),
        .y(data_out)
    );

endmodule
