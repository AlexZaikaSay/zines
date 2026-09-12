
`include "adder.sv"
`include "alu.sv"
`include "mux2_1.sv"
`include "ff.sv"
`include "ff_status.sv"
`include "main_fsm.sv"


module mos6502 #(
    parameter PC_START = 16'h0000
) (
    input logic rst,
    input logic clk,
    output logic [15:0] addr,
    output logic [7:0] data_out,
    input logic [7:0] data_in,
    output logic we
);
    logic [7:0] pc_h;
    logic [7:0] pc_l;
    logic [7:0] next_pc_h;
    logic [7:0] next_pc_l;
    logic [7:0] next_pc_h_a;
    logic [7:0] next_pc_l_a;
    logic [7:0] inst;
    logic [7:0] flags;
    logic [7:0] alu_result;
    logic [7:0] alu_a;
    logic [7:0] alu_b;
    logic [7:0] a;
    logic [7:0] x;
    logic [7:0] y;
    logic [7:0] a_in;
    logic [7:0] x_in;
    logic [7:0] y_in;

    logic pc_adder_l_cout;


    logic c;
    logic z;
    logic i;
    logic d;
    logic v;
    logic n;
    logic w_c;
    logic w_z;
    logic w_i;
    logic w_d;
    logic w_v;
    logic w_n;

    logic w_next_pc;
    logic w_inst;
    logic w_a;
    logic w_x;
    logic w_y;

    logic src_addr_h;
    logic src_addr_l;
    logic src_next_pc_h;
    logic src_next_pc_l;
    logic src_a;
    logic src_x;
    logic src_y;
    logic src_alu_a;
    logic src_alu_b;

    logic [2:0] alu_op;

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

    mux2_1 next_pc_h_mux2_1(
        .a(next_pc_h_a),        // TODO: set input signal a
        .b(8'h00),              // TODO: set input signal b
        .sel(src_next_pc_h),
        .y(next_pc_h)
    );

    mux2_1 next_pc_l_mux2_1(
        .a(next_pc_l_a),         // TODO: set input signal a
        .b(8'h00),              // TODO: set input signal b
        .sel(src_next_pc_l),
        .y(next_pc_l)
    );

    ff #(
        .RESET_VALUE(PC_START[15:8])
    ) pc_h_ff (
        .clk(clk),
        .rst(rst),
        .d(next_pc_h),
        .en(w_next_pc),
        .q(pc_h)
    );

    ff #(
        .RESET_VALUE(PC_START[7:0])
    ) pc_l_ff (
        .clk(clk),
        .rst(rst),
        .d(next_pc_l),
        .en(w_next_pc),
        .q(pc_l)
    );

    mux2_1 addr_h_mux2_1(
        .a(pc_h),
        .b(8'h00),  // TODO: set input signal b
        .sel(src_addr_h), 
        .y(addr[15:8])
    );

    mux2_1 addr_l_mux2_1(
        .a(pc_l),
        .b(8'h00),  // TODO: set input signal b
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

    ff_status status_ff (
        .clk(clk),
        .rst(rst),
        .c(c),
        .z(z),
        .i(i),
        .d(d),
        .v(v),
        .n(n),
        .w_c(w_c),
        .w_z(w_z),
        .w_i(w_i),
        .w_d(w_d),
        .w_v(w_v),
        .w_n(w_n),
        .q(flags)
    );

    mux2_1 src_a_mux2_1(
        .a(alu_result),
        .b(8'h00),     // TODO: set input signal b
        .sel(src_a),
        .y(a_in)
    );

    ff a_ff (
        .clk(clk),
        .rst(rst),
        .d(a_in),
        .en(w_a),
        .q(a)
    );

    mux2_1 src_x_mux2_1(
        .a(alu_result),
        .b(8'h00),     // TODO: set input signal b
        .sel(src_x),
        .y(x_in)
    );

    ff x_ff (
        .clk(clk),
        .rst(rst),
        .d(x_in),
        .en(w_x),
        .q(x)
    );

    mux2_1 src_y_mux2_1(
        .a(alu_result),
        .b(8'h00),     // TODO: set input signal b
        .sel(src_y),
        .y(y_in)
    );

    ff y_ff (
        .clk(clk),
        .rst(rst),
        .d(y_in),
        .en(w_y),
        .q(y)
    );

    main_fsm fsm (
        .clk(clk),
        .rst(rst),
        .imm(data_in),
        .inst(inst),
        .c(c),
        .i(i),
        .v(v),
        .d(d),
        .w_c(w_c),
        .w_z(w_z),
        .w_i(w_i),
        .w_d(w_d),
        .w_v(w_v),
        .w_n(w_n),
        .w_a(w_a),
        .w_x(w_x),
        .w_y(w_y),
        .w_next_pc(w_next_pc),
        .w_inst(w_inst),
        .src_addr_h(src_addr_h),
        .src_addr_l(src_addr_l),
        .src_next_pc_h(src_next_pc_h),
        .src_next_pc_l(src_next_pc_l),
        .src_a(src_a),
        .src_x(src_x),
        .src_y(src_y),
        .src_alu_a(src_alu_a),
        .src_alu_b(src_alu_b),
        .alu_op(alu_op)
    );

    mux2_1 src_alu_a_mux2_1(
        .a(a),
        .b(8'h00),     // TODO: set input signal b
        .sel(src_alu_a),
        .y(alu_a)
    );

    mux2_1 src_alu_b_mux2_1(
        .a(data_in),
        .b(8'h00),     // TODO: set input signal b
        .sel(src_alu_b),
        .y(alu_b)
    );

    alu alu_device (
        .alu_op(alu_op),
        .a(alu_a),
        .b(alu_b),
        .result(alu_result),
        .n(n),
        .z(z)
    );

endmodule
