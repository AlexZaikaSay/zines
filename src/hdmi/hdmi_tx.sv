// HDMI 1.x transmitter for 640x480p60 (CEA VIC 1) with 2-channel 48 kHz L-PCM audio.
//
// Input is a raster position (cx, cy) on the 800x525 grid and the RGB of that pixel,
// valid in the same cycle. Sync and blanking are generated here from cx/cy, so the
// source only has to supply pixels (black outside 640x480).
// Output is three 10-bit TMDS symbols per pixel clock, registered, sent LSB first by
// an external 10:1 serializer (the TMDS clock lane carries 10'b0000011111).
//
// Every line carries one data island in horizontal blanking:
//   cx 640-643 control, 644-651 data island preamble, 652-653 guard band,
//   654-685 packet slot 0 (audio samples or null), 686-717 packet slot 1
//   (ACR / AVI InfoFrame / Audio InfoFrame / null), 718-719 guard band.
// Lines followed by active video end with the video preamble (790-797) and the
// video guard band (798-799).
//
// Audio: one sample (mono, sent on both channels) per audio_valid pulse. Samples are
// buffered and sent up to four per audio packet, at most 2 arrive per line.
module hdmi_tx #(
    parameter integer PIXEL_CLK_HZ = 25_200_000,
    parameter integer AUDIO_RATE   = 48_000
) (
    input  logic        clk,            // pixel clock
    input  logic        rst_n,

    input  logic [9:0]  cx,
    input  logic [9:0]  cy,
    input  logic [7:0]  red,
    input  logic [7:0]  green,
    input  logic [7:0]  blue,

    input  logic [15:0] audio_sample,   // signed 16-bit
    input  logic        audio_valid,

    output logic [9:0]  tmds_ch0,       // blue  + hsync/vsync + packet header
    output logic [9:0]  tmds_ch1,       // green + packet subpacket even bits
    output logic [9:0]  tmds_ch2        // red   + packet subpacket odd bits
);

    // ----------------------------------------------------------------
    // 640x480p60 timing (negative sync polarity)
    // ----------------------------------------------------------------
    localparam integer H_VIS      = 640;
    localparam integer H_SYNC_BEG = 656;
    localparam integer H_SYNC_END = 752;
    localparam integer H_TOTAL    = 800;
    localparam integer V_VIS      = 480;
    localparam integer V_SYNC_BEG = 490;
    localparam integer V_SYNC_END = 492;
    localparam integer V_TOTAL    = 525;

    localparam integer ISLAND_PRE   = 644;              // 8-clock preamble
    localparam integer ISLAND_GUARD = ISLAND_PRE + 8;   // 2-clock leading guard band
    localparam integer ISLAND_DATA  = ISLAND_GUARD + 2; // 2 packets x 32 clocks
    localparam integer ISLAND_TRAIL = ISLAND_DATA + 64; // 2-clock trailing guard band
    localparam integer ISLAND_END   = ISLAND_TRAIL + 2;
    localparam integer VIDEO_PRE    = H_TOTAL - 10;     // 8-clock preamble
    localparam integer VIDEO_GUARD  = H_TOTAL - 2;      // 2-clock guard band

    // Audio Clock Regeneration: fs = f_pixel * N / (128 * CTS)
    localparam logic [19:0] ACR_N   = 20'd6144;
    localparam logic [19:0] ACR_CTS = 20'(64'(PIXEL_CLK_HZ) * 6144 / (128 * AUDIO_RATE));
    localparam integer      ACR_PERIOD = PIXEL_CLK_HZ / 1000;   // send about every 1 ms

    // Lines that carry the InfoFrames once per frame (vertical blanking)
    localparam logic [9:0] AVI_LINE   = 10'd500;
    localparam logic [9:0] AUDIO_LINE = 10'd501;

    wire hsync = !((cx >= 10'(H_SYNC_BEG)) && (cx < 10'(H_SYNC_END)));
    wire vsync = !((cy >= 10'(V_SYNC_BEG)) && (cy < 10'(V_SYNC_END)));

    wire video_line      = (cy < 10'(V_VIS));
    wire next_video_line = (cy < 10'(V_VIS - 1)) || (cy == 10'(V_TOTAL - 1));

    wire video_period  = video_line && (cx < 10'(H_VIS));
    wire video_pre     = next_video_line && (cx >= 10'(VIDEO_PRE)) && (cx < 10'(VIDEO_GUARD));
    wire video_guard   = next_video_line && (cx >= 10'(VIDEO_GUARD));
    wire island_pre    = (cx >= 10'(ISLAND_PRE))   && (cx < 10'(ISLAND_GUARD));
    wire island_guard  = ((cx >= 10'(ISLAND_GUARD)) && (cx < 10'(ISLAND_DATA))) ||
                         ((cx >= 10'(ISLAND_TRAIL)) && (cx < 10'(ISLAND_END)));
    wire island_data   = (cx >= 10'(ISLAND_DATA))  && (cx < 10'(ISLAND_TRAIL));
    wire packet_latch  = (cx == 10'(ISLAND_PRE - 1));

    wire [9:0] island_pos = cx - 10'(ISLAND_DATA);
    wire       slot       = island_pos[5];
    wire [4:0] bit_index  = island_pos[4:0];

    // ----------------------------------------------------------------
    // Packet helpers (HDMI 1.4 section 5.3)
    // ----------------------------------------------------------------
    // BCH ECC, generator 1 + x^6 + x^7 + x^8, bits fed LSB first
    function automatic [7:0] bch_ecc24(input [23:0] data);
        logic [7:0] ecc;
        ecc = 8'd0;
        for (int i = 0; i < 24; i++)
            ecc = (ecc >> 1) ^ (((ecc[0] ^ data[i]) != 1'b0) ? 8'h83 : 8'h00);
        return ecc;
    endfunction

    function automatic [7:0] bch_ecc56(input [55:0] data);
        logic [7:0] ecc;
        ecc = 8'd0;
        for (int i = 0; i < 56; i++)
            ecc = (ecc >> 1) ^ (((ecc[0] ^ data[i]) != 1'b0) ? 8'h83 : 8'h00);
        return ecc;
    endfunction

    // One packet: 32-bit header lane (HB0..HB2 + ECC) and four 64-bit subpackets
    typedef struct packed {
        logic [31:0] header;
        logic [63:0] sub3;
        logic [63:0] sub2;
        logic [63:0] sub1;
        logic [63:0] sub0;
    } packet_t;

    function automatic packet_t make_packet(input [23:0] hb,
                                            input [55:0] sb0, input [55:0] sb1,
                                            input [55:0] sb2, input [55:0] sb3);
        packet_t p;
        p.header = {bch_ecc24(hb), hb};
        p.sub0   = {bch_ecc56(sb0), sb0};
        p.sub1   = {bch_ecc56(sb1), sb1};
        p.sub2   = {bch_ecc56(sb2), sb2};
        p.sub3   = {bch_ecc56(sb3), sb3};
        return p;
    endfunction

    // InfoFrame: PB0 is the checksum, PB1..PB27 follow in subpackets 0..3 (7 bytes each)
    function automatic packet_t make_infoframe(input [7:0] frame_type, input [7:0] version,
                                               input [7:0] length, input [8*27-1:0] pb);
        logic [7:0] sum;
        logic [8*28-1:0] body;
        sum = frame_type + version + length;
        for (int i = 0; i < 27; i++)
            sum = sum + pb[8*i +: 8];
        body = {pb, 8'(-sum)};
        return make_packet({length, version, frame_type},
                           body[0 +: 56], body[56 +: 56], body[112 +: 56], body[168 +: 56]);
    endfunction

    // AVI InfoFrame v2: RGB, active format = picture, 4:3, VIC 1
    wire [8*27-1:0] avi_pb = {{23{8'h00}}, 8'h01, 8'h00, 8'h18, 8'h10};
    // Audio InfoFrame v1: coding/size/rate from stream header, 2 channels, FL/FR
    wire [8*27-1:0] aif_pb = {{26{8'h00}}, 8'h01};

    wire [55:0] acr_sb = {ACR_N[7:0], ACR_N[15:8], {4'h0, ACR_N[19:16]},
                          ACR_CTS[7:0], ACR_CTS[15:8], {4'h0, ACR_CTS[19:16]}, 8'h00};

    // IEC 60958 channel status (consumer, PCM, no copyright, 48 kHz, 16-bit)
    function automatic logic channel_status(input [7:0] frame);
        return (frame == 8'd2) || (frame == 8'd25) || (frame == 8'd33);
    endfunction

    // 2-channel audio subpacket: left = right = sample, 24-bit left-justified
    function automatic [55:0] audio_subpacket(input [15:0] sample, input c);
        logic [23:0] s;
        logic        p;
        s = {sample, 8'h00};
        p = ^{s, c};                        // even parity over sample, V = 0, U = 0, C
        return {p, c, 1'b0, 1'b0, p, c, 1'b0, 1'b0, s, s};
    endfunction

    // ----------------------------------------------------------------
    // Audio sample buffer (filled between islands, emptied into slot 0)
    // ----------------------------------------------------------------
    logic [15:0] buf_sample [0:3];
    logic [3:0]  buf_start;                 // B flag: first frame of a 192-frame block
    logic [3:0]  buf_cs;                    // channel status bit of the frame
    logic [2:0]  buf_count;
    logic [7:0]  frame_index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_count   <= 3'd0;
            frame_index <= 8'd0;
        end
        else begin
            if (packet_latch)
                buf_count <= audio_valid ? 3'd1 : 3'd0;
            else if (audio_valid && buf_count != 3'd4)
                buf_count <= buf_count + 3'd1;

            if (audio_valid)
                frame_index <= (frame_index == 8'd191) ? 8'd0 : frame_index + 8'd1;
        end
    end

    wire [1:0] buf_wr = packet_latch ? 2'd0 : buf_count[1:0];

    always_ff @(posedge clk) begin
        if (audio_valid && (packet_latch || buf_count != 3'd4)) begin
            buf_sample[buf_wr] <= audio_sample;
            buf_start[buf_wr]  <= (frame_index == 8'd0);
            buf_cs[buf_wr]     <= channel_status(frame_index);
        end
    end

    wire [3:0] present = (buf_count == 3'd0) ? 4'b0000 :
                         (buf_count == 3'd1) ? 4'b0001 :
                         (buf_count == 3'd2) ? 4'b0011 :
                         (buf_count == 3'd3) ? 4'b0111 : 4'b1111;

    packet_t audio_packet, acr_packet, avi_packet, aif_packet, null_packet;

    // Header: HB0 = 0x02, HB1 = sample_present (layout 0 = 2 channels), HB2 = B flags
    assign audio_packet = make_packet(
        {present & buf_start, 4'h0, 4'h0, present, 8'h02},
        present[0] ? audio_subpacket(buf_sample[0], buf_cs[0]) : 56'd0,
        present[1] ? audio_subpacket(buf_sample[1], buf_cs[1]) : 56'd0,
        present[2] ? audio_subpacket(buf_sample[2], buf_cs[2]) : 56'd0,
        present[3] ? audio_subpacket(buf_sample[3], buf_cs[3]) : 56'd0);

    assign acr_packet  = make_packet(24'h000001, acr_sb, acr_sb, acr_sb, acr_sb);
    assign avi_packet  = make_infoframe(8'h82, 8'h02, 8'd13, avi_pb);
    assign aif_packet  = make_infoframe(8'h84, 8'h01, 8'd10, aif_pb);
    assign null_packet = '0;

    // ----------------------------------------------------------------
    // Packet scheduling, latched once per line before the island
    // ----------------------------------------------------------------
    logic [31:0] acr_timer;
    logic        acr_pending;
    packet_t     slot0, slot1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acr_timer   <= 32'd0;
            acr_pending <= 1'b1;
            slot0       <= '0;
            slot1       <= '0;
        end
        else begin
            if (acr_timer == 32'(ACR_PERIOD - 1))
                acr_timer <= 32'd0;
            else
                acr_timer <= acr_timer + 32'd1;

            if (packet_latch) begin
                slot0 <= (buf_count != 3'd0) ? audio_packet : null_packet;

                if (cy == AVI_LINE)
                    slot1 <= avi_packet;
                else if (cy == AUDIO_LINE)
                    slot1 <= aif_packet;
                else if (acr_pending)
                    slot1 <= acr_packet;
                else
                    slot1 <= null_packet;
            end

            if (acr_timer == 32'(ACR_PERIOD - 1))
                acr_pending <= 1'b1;
            else if (packet_latch && cy != AVI_LINE && cy != AUDIO_LINE)
                acr_pending <= 1'b0;
        end
    end

    packet_t pkt;
    assign pkt = slot ? slot1 : slot0;

    wire [5:0] even_bit = {bit_index, 1'b0};
    wire [5:0] odd_bit  = {bit_index, 1'b1};

    wire [3:0] island_ch0 = {bit_index != 5'd0, pkt.header[bit_index], vsync, hsync};
    wire [3:0] island_ch1 = {pkt.sub3[even_bit], pkt.sub2[even_bit], pkt.sub1[even_bit], pkt.sub0[even_bit]};
    wire [3:0] island_ch2 = {pkt.sub3[odd_bit],  pkt.sub2[odd_bit],  pkt.sub1[odd_bit],  pkt.sub0[odd_bit]};

    // ----------------------------------------------------------------
    // Symbol encoding
    // ----------------------------------------------------------------
    function automatic [9:0] tmds_control(input [1:0] c);
        case (c)
            2'b00:   return 10'b1101010100;
            2'b01:   return 10'b0010101011;
            2'b10:   return 10'b0101010100;
            default: return 10'b1010101011;
        endcase
    endfunction

    function automatic [9:0] terc4(input [3:0] d);
        case (d)
            4'h0: return 10'b1010011100;
            4'h1: return 10'b1001100011;
            4'h2: return 10'b1011100100;
            4'h3: return 10'b1011100010;
            4'h4: return 10'b0101110001;
            4'h5: return 10'b0100011110;
            4'h6: return 10'b0110001110;
            4'h7: return 10'b0100111100;
            4'h8: return 10'b1011001100;
            4'h9: return 10'b0100111001;
            4'hA: return 10'b0110011100;
            4'hB: return 10'b1011000110;
            4'hC: return 10'b1010001110;
            4'hD: return 10'b1001110001;
            4'hE: return 10'b0101100011;
            default: return 10'b1011000011;
        endcase
    endfunction

    logic [9:0] video_ch0, video_ch1, video_ch2;

    tmds_video_encoder u_enc_blue  (.clk, .rst_n, .de(video_period), .d(blue),  .symbol(video_ch0));
    tmds_video_encoder u_enc_green (.clk, .rst_n, .de(video_period), .d(green), .symbol(video_ch1));
    tmds_video_encoder u_enc_red   (.clk, .rst_n, .de(video_period), .d(red),   .symbol(video_ch2));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tmds_ch0 <= tmds_control(2'b11);
            tmds_ch1 <= tmds_control(2'b00);
            tmds_ch2 <= tmds_control(2'b00);
        end
        else if (video_period) begin
            tmds_ch0 <= video_ch0;
            tmds_ch1 <= video_ch1;
            tmds_ch2 <= video_ch2;
        end
        else if (video_guard) begin
            tmds_ch0 <= 10'b1011001100;
            tmds_ch1 <= 10'b0100110011;
            tmds_ch2 <= 10'b1011001100;
        end
        else if (island_guard) begin
            tmds_ch0 <= terc4({2'b11, vsync, hsync});
            tmds_ch1 <= 10'b0100110011;
            tmds_ch2 <= 10'b0100110011;
        end
        else if (island_data) begin
            tmds_ch0 <= terc4(island_ch0);
            tmds_ch1 <= terc4(island_ch1);
            tmds_ch2 <= terc4(island_ch2);
        end
        else begin
            // Control period; preambles set CTL0..CTL3 = 1000 (video) or 1010 (data island)
            tmds_ch0 <= tmds_control({vsync, hsync});
            tmds_ch1 <= tmds_control({1'b0, video_pre || island_pre});
            tmds_ch2 <= tmds_control({1'b0, island_pre});
        end
    end

    wire unused = &{1'b0, island_pos[9:6]};

endmodule


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
