// CPU side of a real NES controller: answers $4016/$4017 like a CD4021.
// While OUT0 (strobe) is high it keeps loading the buttons and returns A; each
// read returns the current bit and shifts when /OE rises; after 8 reads it returns 1.
// The buttons come from nes_pad_poller (bit order and polarity are described there).
module nes_pad_port (
    input  logic       clk,                      // faster than the CPU clock (ppu_clk)
    input  logic       rst_n,
    input  logic       strobe,                   // CPU OUT0 ($4016 bit 0)
    input  logic       oe_n,                     // CPU /OE for this port, low during a read
    input  logic [7:0] buttons,
    output logic       data                      // D0, 1 = pressed
);
    logic [7:0] shift;
    logic       oe_n_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift  <= 8'hFF;
            oe_n_q <= 1'b1;
        end
        else begin
            oe_n_q <= oe_n;
            if (strobe)
                shift <= buttons;
            else if (oe_n && !oe_n_q)            // read finished
                shift <= {1'b1, shift[7:1]};
        end
    end

    assign data = strobe ? buttons[0] : shift[0];

endmodule
