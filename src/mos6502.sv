
`include "adder.sv"
`include "alu.sv"
`include "mux2_1.sv"
`include "mux3_1.sv"
`include "mux4_1.sv"
`include "mux5_1.sv"
`include "mux8_1.sv"
`include "ff.sv"
`include "ff_status.sv"
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
    logic [7:0] next_pc_h;
    logic [7:0] next_pc_l;
    logic [7:0] next_pc_h_a;
    logic [7:0] next_pc_l_a;
    logic [7:0] next_high_byte;
    logic [7:0] next_low_byte;
    logic [7:0] inst;
    logic [7:0] high_byte;
    logic [7:0] low_byte;
    logic [7:0] low_byte_ind;
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

    logic pc_adder_l_cout;

    logic c;
    logic z;
    logic i;
    logic d;
    logic b;
    logic v;
    logic n;
    logic w_c;
    logic w_z;
    logic w_i;
    logic w_d;
    logic w_b;
    logic w_v;
    logic w_n;

    logic c_in;

    logic w_next_pc_h;
    logic w_next_pc_l;
    logic w_inst;
    logic w_high_byte;
    logic w_low_byte;
    logic w_low_byte_ind;
    logic w_a;
    logic w_x;
    logic w_y;
    logic w_s;

    logic [1:0] src_high_byte;
    logic       src_low_byte;
    logic [2:0] src_addr_h;
    logic [2:0] src_addr_l;
    logic [1:0] src_next_pc_h;
    logic [1:0] src_next_pc_l;
    logic [2:0] src_alu_a;
    logic [2:0] src_alu_b;
    logic [1:0] src_c_in;
    logic [2:0] src_data_out;

    logic [4:0] alu_op;

    int_control int_control_inst(
        .irq_addr_h(irq_addr_h),
        .irq_addr_l(irq_addr_l)
    );

    adder pc_h_adder(
        .a(pc_h),
        .cin(pc_adder_l_cout),
        .sum(next_pc_h_a),
        .cout() 
    );

    adder pc_l_adder(
        .a(pc_l),
        .cin(1'b1),
        .sum(next_pc_l_a),
        .cout(pc_adder_l_cout)
    );

    mux3_1 next_pc_h_mux3_1(
        .a(next_pc_h_a),
        .b(data_in),
        .c(alu_result),
        .sel(src_next_pc_h),
        .y(next_pc_h)
    );

    mux4_1 next_pc_l_mux4_1(
        .a(next_pc_l_a),
        .b(low_byte),
        .c(alu_result),
        .d(data_in),
        .sel(src_next_pc_l),
        .y(next_pc_l)
    );

    ff #(
        .RESET_VALUE(PC_START[15:8])
    ) pc_h_ff (
        .clk(clk),
        .rst(rst),
        .d(next_pc_h),
        .en(w_next_pc_h),
        .q(pc_h)
    );

    ff #(
        .RESET_VALUE(PC_START[7:0])
    ) pc_l_ff (
        .clk(clk),
        .rst(rst),
        .d(next_pc_l),
        .en(w_next_pc_l),
        .q(pc_l)
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

    ff inst_ff (
        .clk(clk),
        .rst(rst),
        .d(data_in),
        .en(w_inst),
        .q(inst)
    );

    mux2_1 low_byte_mux2_1(
        .a(data_in),
        .b(alu_result),
        .sel(src_low_byte),
        .y(next_low_byte)
    );

    ff low_byte_ff (
        .clk(clk),
        .rst(rst),
        .d(next_low_byte),
        .en(w_low_byte),
        .q(low_byte)
    );

    ff low_byte_ind_ff (
        .clk(clk),
        .rst(rst),
        .d(data_in),
        .en(w_low_byte_ind),
        .q(low_byte_ind)
    );

    mux3_1 high_byte_mux3_1(
        .a(data_in),
        .b(8'b0),
        .c(alu_result),
        .sel(src_high_byte),
        .y(next_high_byte)
    );

    ff high_byte_ff (
        .clk(clk),
        .rst(rst),
        .d(next_high_byte),
        .en(w_high_byte),
        .q(high_byte)
    );

    ff_status status_ff (
        .clk(clk),
        .rst(rst),
        .c(c),
        .z(z),
        .i(i),
        .d(d),
        .b(b),
        .v(v),
        .n(n),
        .w_c(w_c),
        .w_z(w_z),
        .w_i(w_i),
        .w_d(w_d),
        .w_b(w_b),
        .w_v(w_v),
        .w_n(w_n),
        .q(flags)
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

    main_fsm fsm (
        .clk(clk),
        .rst(rst),
        .imm(data_in),
        .inst(inst),
        .flags(flags),
        .c(c),
        .v(v),
        .w_c(w_c),
        .w_z(w_z),
        .w_i(w_i),
        .w_d(w_d),
        .w_b(w_b),
        .w_v(w_v),
        .w_n(w_n),
        .w_a(w_a),
        .w_x(w_x),
        .w_y(w_y),
        .w_s(w_s),
        .w_mem(we),
        .w_next_pc_h(w_next_pc_h),
        .w_next_pc_l(w_next_pc_l),
        .w_inst(w_inst),
        .w_high_byte(w_high_byte),
        .w_low_byte(w_low_byte),
        .w_low_byte_ind(w_low_byte_ind),
        .src_c_in(src_c_in),
        .src_high_byte(src_high_byte),
        .src_low_byte(src_low_byte),
        .src_data_out(src_data_out),
        .src_addr_h(src_addr_h),
        .src_addr_l(src_addr_l),
        .src_next_pc_h(src_next_pc_h),
        .src_next_pc_l(src_next_pc_l),
        .src_alu_a(src_alu_a),
        .src_alu_b(src_alu_b),
        .alu_op(alu_op),
        .undef(undef)
    );

    mux8_1 src_alu_a_mux8_1(
        .a(a),
        .b(x),
        .c(y),
        .d(s),
        .e(pc_l),
        .f(pc_h),
        .g(low_byte),
        .h(high_byte),
        .sel(src_alu_a),
        .y(alu_a)
    );

    mux5_1 src_alu_b_mux5_1(
        .a(data_in),
        .b(low_byte),
        .c(8'h00),
        .d(8'h01),
        .e(low_byte_ind),
        .sel(src_alu_b),
        .y(alu_b)
    );

    alu alu_device (
        .alu_op(alu_op),
        .a_in(alu_a),
        .b_in(alu_b),
        .c_in(c_in),
        .result(alu_result),
        .i(i),
        .d(d),
        .b(b),
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
