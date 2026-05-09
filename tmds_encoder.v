// -----------------------------------------------------------------------------
// 8b/10b TMDS encoder for DVI/HDMI video data.
//
// Fix in this version:
//   Verilog unsigned subtraction can wrap when calculating disparity.
//   This encoder sign-extends the ones/zeros balance before using it.
// -----------------------------------------------------------------------------

module tmds_encoder (
    input  wire       clk,
    input  wire       resetn,
    input  wire       de,
    input  wire [1:0] ctrl,
    input  wire [7:0] din,
    output reg  [9:0] dout
);

    function [3:0] count_ones;
        // Count set bits in one byte; used by TMDS transition minimization.
        input [7:0] bits;
        integer i;
        begin
            count_ones = 4'd0;
            for (i = 0; i < 8; i = i + 1)
                count_ones = count_ones + bits[i];
        end
    endfunction

    reg signed [7:0] disparity = 8'sd0;
    reg [8:0] q_m;
    reg [3:0] n1_d;
    reg [3:0] n1_qm;
    reg [3:0] n0_qm;
    reg signed [7:0] balance;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            disparity <= 8'sd0;
            dout      <= 10'b1101010100;
        end else begin
            if (!de) begin
                // During blanking, HDMI/DVI sends one of four control symbols.
                // H-sync and V-sync are carried on the blue channel only.
                disparity <= 8'sd0;
                case (ctrl)
                    2'b00: dout <= 10'b1101010100;
                    2'b01: dout <= 10'b0010101011;
                    2'b10: dout <= 10'b0101010100;
                    2'b11: dout <= 10'b1010101011;
                    default: dout <= 10'b1101010100;
                endcase
            end else begin
                // First stage: transition minimization.
                n1_d = count_ones(din);

                q_m[0] = din[0];
                if ((n1_d > 4'd4) || ((n1_d == 4'd4) && (din[0] == 1'b0))) begin
                    q_m[1] = q_m[0] ~^ din[1];
                    q_m[2] = q_m[1] ~^ din[2];
                    q_m[3] = q_m[2] ~^ din[3];
                    q_m[4] = q_m[3] ~^ din[4];
                    q_m[5] = q_m[4] ~^ din[5];
                    q_m[6] = q_m[5] ~^ din[6];
                    q_m[7] = q_m[6] ~^ din[7];
                    q_m[8] = 1'b0;
                end else begin
                    q_m[1] = q_m[0] ^ din[1];
                    q_m[2] = q_m[1] ^ din[2];
                    q_m[3] = q_m[2] ^ din[3];
                    q_m[4] = q_m[3] ^ din[4];
                    q_m[5] = q_m[4] ^ din[5];
                    q_m[6] = q_m[5] ^ din[6];
                    q_m[7] = q_m[6] ^ din[7];
                    q_m[8] = 1'b1;
                end

                n1_qm  = count_ones(q_m[7:0]);
                n0_qm  = 4'd8 - n1_qm;

                // Signed balance = ones - zeros. Range is -8..+8.
                balance = $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});

                // Second stage: DC balancing.
                // The running disparity keeps the serial stream balanced so the
                // receiver can recover the clock and data reliably.
                if ((disparity == 8'sd0) || (balance == 8'sd0)) begin
                    dout[9]   <= ~q_m[8];
                    dout[8]   <=  q_m[8];
                    dout[7:0] <= (q_m[8]) ? q_m[7:0] : ~q_m[7:0];

                    if (q_m[8])
                        disparity <= disparity + balance;
                    else
                        disparity <= disparity - balance;
                end else if (((disparity > 8'sd0) && (balance > 8'sd0)) ||
                             ((disparity < 8'sd0) && (balance < 8'sd0))) begin
                    dout[9]   <= 1'b1;
                    dout[8]   <= q_m[8];
                    dout[7:0] <= ~q_m[7:0];

                    // Invert 8 data bits. Add the extra two-bit effect from q_m[8].
                    if (q_m[8])
                        disparity <= disparity - balance + 8'sd2;
                    else
                        disparity <= disparity - balance;
                end else begin
                    dout[9]   <= 1'b0;
                    dout[8]   <= q_m[8];
                    dout[7:0] <= q_m[7:0];

                    if (q_m[8])
                        disparity <= disparity + balance;
                    else
                        disparity <= disparity + balance - 8'sd2;
                end
            end
        end
    end

endmodule
