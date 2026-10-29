// TMDS 8b/10b video-period encoder (DVI 1.0 section 3.2.2), symbol is combinational
// for the current d; the running disparity advances on each clock with de = 1 and is
// cleared outside video periods.
module tmds_video_encoder (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       de,
    input  logic [7:0] d,
    output logic [9:0] symbol
);
    logic [3:0] n1_d;
    logic [8:0] q_m;
    logic [3:0] n1_qm;
    logic       use_xnor;

    // q_m[i] reads q_m[i-1], which the loop has already assigned: not a latch
    /* verilator lint_off ALWCOMBORDER */
    always_comb begin
        n1_d = 4'd0;
        for (int i = 0; i < 8; i++)
            n1_d = n1_d + {3'd0, d[i]};
        use_xnor = (n1_d > 4'd4) || (n1_d == 4'd4 && d[0] == 1'b0);

        q_m[0] = d[0];
        for (int i = 1; i < 8; i++)
            q_m[i] = use_xnor ? ~(q_m[i-1] ^ d[i]) : (q_m[i-1] ^ d[i]);
        q_m[8] = ~use_xnor;

        n1_qm = 4'd0;
        for (int i = 0; i < 8; i++)
            n1_qm = n1_qm + {3'd0, q_m[i]};
    end
    /* verilator lint_on ALWCOMBORDER */

    // Disparity is tracked as (#1s - #0s) / 2 of the symbols sent so far
    logic signed [4:0] cnt;
    logic signed [4:0] diff;                    // (#1s - #0s) of q_m[7:0], halved
    logic signed [4:0] cnt_next;

    always_comb begin
        diff = $signed({1'b0, n1_qm}) - 5'sd4;
        if (cnt == 5'sd0 || diff == 5'sd0) begin
            symbol   = {~q_m[8], q_m[8], q_m[8] ? q_m[7:0] : ~q_m[7:0]};
            cnt_next = q_m[8] ? cnt + diff : cnt - diff;
        end
        else if ((cnt > 5'sd0 && diff > 5'sd0) || (cnt < 5'sd0 && diff < 5'sd0)) begin
            symbol   = {1'b1, q_m[8], ~q_m[7:0]};
            cnt_next = cnt - diff + (q_m[8] ? 5'sd1 : 5'sd0);
        end
        else begin
            symbol   = {1'b0, q_m[8], q_m[7:0]};
            cnt_next = cnt + diff - (q_m[8] ? 5'sd0 : 5'sd1);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 5'sd0;
        else
            cnt <= de ? cnt_next : 5'sd0;
    end

endmodule
