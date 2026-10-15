// Simulated NES controller (CD4021 shift register).
//
//  * strob_n falling : the CPU wrote $4016 bit0 = 1 -> 0, so snapshot `buttons`.
//  * strob_n high    : the snapshot keeps following `buttons`; reads return button A.
//  * oe_n falling    : a read of $4016. Return the current bit, then shift.
//
// Bit order of `buttons` (and of the serial stream): A, B, Select, Start, Up, Down, Left, Right.
// A pressed button reads as 1. After 8 reads an official pad returns 1.
module joystick_sim (
    input  logic       strob,
    input  logic       oe_n,
    input  logic [7:0] buttons,
    output logic [7:0] data
);
    logic [7:0] shift;
    logic [7:0] data_q;
    logic       latch_req;          // toggled by the strobe event
    logic       latch_ack;          // toggled by the read event once it applied the snapshot

    // Power-on state (simulation model, there is no reset pin)
    initial begin
        shift     = 8'hFF;
        data_q    = 8'h00;
        latch_req = 1'b0;
        latch_ack = 1'b0;
    end

    always @(negedge strob)
        latch_req <= ~latch_req;

    // Single block owns `shift` so it has one driver; a pending strobe is applied
    // on the first read after it.
    always @(negedge oe_n) begin
        logic [7:0] cur;
        cur = (latch_req != latch_ack) ? buttons : shift;
        if (strob) begin
            // strobe still high: the register keeps reloading, so every read returns A
            data_q <= {7'b0, buttons[0]};
            shift  <= buttons;
        end else begin
            data_q <= {7'b0, cur[0]};
            shift  <= {1'b1, cur[7:1]};
        end
        latch_ack <= latch_req;
    end

    assign data = data_q;

endmodule
