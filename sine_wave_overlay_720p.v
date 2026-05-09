// -----------------------------------------------------------------------------
// 720p60 procedural waveform overlay - synchronized square-wave demo
//
// Clean visual demo with three synchronized traces:
//   TOP:    Signal Generator lane with a green square wave and a yellow sine
//           wave underneath it. Both use the same variable duty sweep.
//   MIDDLE: Simple PLL (clean 50/50 output)
//   BOTTOM: Patent (tracks the distorted input half-cycle timing)
//
// Birdie markers are drawn at the positive and negative peaks of all three
// main traces. This version favors clean display rendering over heavy proof logic.
// -----------------------------------------------------------------------------

module sine_wave_overlay_720p (
    input  wire        pix_clk,
    input  wire        resetn,
    input  wire        video_active,
    input  wire [10:0] h_cnt,
    input  wire [9:0]  v_cnt,

    input  wire [7:0]  red_in,
    input  wire [7:0]  green_in,
    input  wire [7:0]  blue_in,

    output reg  [7:0]  red_out,
    output reg  [7:0]  green_out,
    output reg  [7:0]  blue_out
);

    // Frame-based duty-cycle sweep for the top signal-generator waveform.
    reg [4:0] duty_index = 5'd0;      // 0..20 maps to 40/60 .. 60/40
    reg       duty_dir   = 1'b0;      // 0 = upward sweep, 1 = downward sweep
    reg [2:0] frame_div  = 3'd0;      // update duty every 4 frames

    wire frame_tick = (h_cnt == 11'd0) && (v_cnt == 10'd0);

    // Update the demo animation only at the start of a frame. This avoids
    // changing the duty-cycle sweep halfway down the picture.

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            duty_index <= 5'd0;
            duty_dir   <= 1'b0;
            frame_div  <= 3'd0;
        end else if (frame_tick) begin
            if (frame_div == 3'd3) begin
                frame_div <= 3'd0;
                if (!duty_dir) begin
                    if (duty_index == 5'd20) begin
                        duty_index <= 5'd19;
                        duty_dir   <= 1'b1;
                    end else begin
                        duty_index <= duty_index + 5'd1;
                    end
                end else begin
                    if (duty_index == 5'd0) begin
                        duty_index <= 5'd1;
                        duty_dir   <= 1'b0;
                    end else begin
                        duty_index <= duty_index - 5'd1;
                    end
                end
            end else begin
                frame_div <= frame_div + 3'd1;
            end
        end
    end

    // Positive pulse width for one full 1280-pixel cycle across the screen.
    // The lookup table below maps the duty index to a displayed pulse width.
    // It is intentionally simple and visible, so the demo is easy to modify.
    reg [10:0] duty_high_pixels;
    always @(*) begin
        case (duty_index)
            5'd0:  duty_high_pixels = 11'd512; // 40% of 1280
            5'd1:  duty_high_pixels = 11'd525;
            5'd2:  duty_high_pixels = 11'd538;
            5'd3:  duty_high_pixels = 11'd550;
            5'd4:  duty_high_pixels = 11'd563;
            5'd5:  duty_high_pixels = 11'd576;
            5'd6:  duty_high_pixels = 11'd589;
            5'd7:  duty_high_pixels = 11'd602;
            5'd8:  duty_high_pixels = 11'd614;
            5'd9:  duty_high_pixels = 11'd627;
            5'd10: duty_high_pixels = 11'd640;
            5'd11: duty_high_pixels = 11'd653;
            5'd12: duty_high_pixels = 11'd666;
            5'd13: duty_high_pixels = 11'd678;
            5'd14: duty_high_pixels = 11'd691;
            5'd15: duty_high_pixels = 11'd704;
            5'd16: duty_high_pixels = 11'd717;
            5'd17: duty_high_pixels = 11'd730;
            5'd18: duty_high_pixels = 11'd742;
            5'd19: duty_high_pixels = 11'd755;
            default: duty_high_pixels = 11'd768; // 60% of 1280
        endcase
    end

    // Phase accumulator for the top sine wave. The sine wave spans one cycle
    // across the active width and uses the same 40/60..60/40 timing distortion
    // as the top square wave.
    reg [15:0] top_phase_acc = 16'd0;
    reg [15:0] top_pos_step;
    reg [15:0] top_neg_step;
    reg [15:0] top_phase_step;

    always @(*) begin
        case (duty_index)
            5'd0:  begin top_pos_step = 16'd64; top_neg_step = 16'd43; end // 40/60
            5'd1:  begin top_pos_step = 16'd62; top_neg_step = 16'd43; end // 41/59
            5'd2:  begin top_pos_step = 16'd61; top_neg_step = 16'd44; end // 42/58
            5'd3:  begin top_pos_step = 16'd60; top_neg_step = 16'd45; end // 43/57
            5'd4:  begin top_pos_step = 16'd58; top_neg_step = 16'd46; end // 44/56
            5'd5:  begin top_pos_step = 16'd57; top_neg_step = 16'd47; end // 45/55
            5'd6:  begin top_pos_step = 16'd56; top_neg_step = 16'd47; end // 46/54
            5'd7:  begin top_pos_step = 16'd54; top_neg_step = 16'd48; end // 47/53
            5'd8:  begin top_pos_step = 16'd53; top_neg_step = 16'd49; end // 48/52
            5'd9:  begin top_pos_step = 16'd52; top_neg_step = 16'd50; end // 49/51
            5'd10: begin top_pos_step = 16'd51; top_neg_step = 16'd51; end // 50/50
            5'd11: begin top_pos_step = 16'd50; top_neg_step = 16'd52; end // 51/49
            5'd12: begin top_pos_step = 16'd49; top_neg_step = 16'd53; end // 52/48
            5'd13: begin top_pos_step = 16'd48; top_neg_step = 16'd54; end // 53/47
            5'd14: begin top_pos_step = 16'd47; top_neg_step = 16'd56; end // 54/46
            5'd15: begin top_pos_step = 16'd47; top_neg_step = 16'd57; end // 55/45
            5'd16: begin top_pos_step = 16'd46; top_neg_step = 16'd58; end // 56/44
            5'd17: begin top_pos_step = 16'd45; top_neg_step = 16'd60; end // 57/43
            5'd18: begin top_pos_step = 16'd44; top_neg_step = 16'd61; end // 58/42
            5'd19: begin top_pos_step = 16'd43; top_neg_step = 16'd62; end // 59/41
            default: begin top_pos_step = 16'd43; top_neg_step = 16'd64; end // 60/40
        endcase
    end

    always @(*) begin
        top_phase_step = top_phase_acc[15] ? top_neg_step : top_pos_step;
    end

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            top_phase_acc <= 16'd0;
        end else if (h_cnt == 11'd0) begin
            top_phase_acc <= 16'd0;
        end else if (video_active) begin
            top_phase_acc <= top_phase_acc + top_phase_step;
        end
    end

    wire [7:0] top_phase_index = top_phase_acc[15:8];

    wire [10:0] x = h_cnt;

    // Trace vertical levels.
    localparam [9:0] TOP_Y_HI = 10'd70;
    localparam [9:0] TOP_Y_LO = 10'd120;
    localparam [9:0] MID_Y_HI = 10'd310;
    localparam [9:0] MID_Y_LO = 10'd360;
    localparam [9:0] BOT_Y_HI = 10'd550;
    localparam [9:0] BOT_Y_LO = 10'd600;

    // Top trace: one-cycle variable-duty signal generator.
    wire top_high = (x < duty_high_pixels);
    wire [9:0] top_y = top_high ? TOP_Y_HI : TOP_Y_LO;
    wire [9:0] top_y_delta = (v_cnt >= top_y) ? (v_cnt - top_y) : (top_y - v_cnt);
    wire [10:0] top_edge_delta = (x >= duty_high_pixels) ? (x - duty_high_pixels) : (duty_high_pixels - x);
    wire top_horiz_on = video_active && (top_y_delta <= 10'd1);
    wire top_vert_on = video_active &&
                       ((x <= 11'd1) || (top_edge_delta <= 11'd1)) &&
                       (v_cnt >= TOP_Y_HI) && (v_cnt <= TOP_Y_LO);
    wire top_trace_on = video_active && (top_horiz_on || top_vert_on);

    // Yellow top sine wave underneath the top square wave. It uses the same
    // distorted timing sweep as the signal generator.
    wire [9:0] top_sine_y = sine_y_top_from_phase(top_phase_index);
    wire [9:0] top_sine_delta = (v_cnt >= top_sine_y) ? (v_cnt - top_sine_y) : (top_sine_y - v_cnt);
    wire top_sine_on = video_active && (top_sine_delta <= 10'd1);

    // Middle trace: one-cycle clean 50/50 simple PLL output, synced to the same screen width.
    wire mid_high = (x < 11'd640);
    wire [9:0] mid_y = mid_high ? MID_Y_HI : MID_Y_LO;
    wire [9:0] mid_y_delta = (v_cnt >= mid_y) ? (v_cnt - mid_y) : (mid_y - v_cnt);
    wire mid_horiz_on = video_active && (mid_y_delta <= 10'd1);
    wire mid_vert_on = video_active &&
                       ((x <= 11'd1) || ((x >= 11'd639) && (x <= 11'd641))) &&
                       (v_cnt >= MID_Y_HI) && (v_cnt <= MID_Y_LO);
    wire mid_trace_on = video_active && (mid_horiz_on || mid_vert_on);

    // Bottom trace: patent demo output visually tied to the distorted input timing.
    wire bot_high = (x < duty_high_pixels);
    wire [9:0] bot_y = bot_high ? BOT_Y_HI : BOT_Y_LO;
    wire [9:0] bot_y_delta = (v_cnt >= bot_y) ? (v_cnt - bot_y) : (bot_y - v_cnt);
    wire [10:0] bot_edge_delta = (x >= duty_high_pixels) ? (x - duty_high_pixels) : (duty_high_pixels - x);
    wire bot_horiz_on = video_active && (bot_y_delta <= 10'd1);
    wire bot_vert_on = video_active &&
                       ((x <= 11'd1) || (bot_edge_delta <= 11'd1)) &&
                       (v_cnt >= BOT_Y_HI) && (v_cnt <= BOT_Y_LO);
    wire bot_trace_on = video_active && (bot_horiz_on || bot_vert_on);

    // -------------------------------------------------------------------------
    // Birdie markers at positive and negative peaks.
    // Drawn as small white plus-sign markers centered on the plateau midpoints.
    // -------------------------------------------------------------------------
    wire [10:0] top_pos_marker_x = (duty_high_pixels + 11'd1) >> 1;
    // The +1 rounds the first top marker on odd widths, avoiding a faint
    // left-side echo without changing the marker shape or thickness.
    wire [10:0] top_neg_marker_x = duty_high_pixels + ((11'd1280 - duty_high_pixels) >> 1);
    wire [10:0] mid_pos_marker_x = 11'd320;
    wire [10:0] mid_neg_marker_x = 11'd960;
    wire [10:0] bot_pos_marker_x = duty_high_pixels >> 1;
    wire [10:0] bot_neg_marker_x = duty_high_pixels + ((11'd1280 - duty_high_pixels) >> 1);

    function birdie_on;
        // Returns true when the current pixel is inside a small plus-sign
        // marker centered at mx,my. The same shape is used for all birdies.
        input [10:0] px;
        input [9:0]  py;
        input [10:0] mx;
        input [9:0]  my;
        reg [10:0] dx;
        reg [9:0]  dy;
        begin
            dx = (px >= mx) ? (px - mx) : (mx - px);
            dy = (py >= my) ? (py - my) : (my - py);
            birdie_on = ((dx <= 11'd1) && (dy <= 10'd7)) ||
                        ((dx <= 11'd5) && (dy <= 10'd1));
        end
    endfunction

    wire birdie_top_pos_on = video_active && birdie_on(h_cnt, v_cnt, top_pos_marker_x, TOP_Y_HI);
    wire birdie_top_neg_on = video_active && birdie_on(h_cnt, v_cnt, top_neg_marker_x, TOP_Y_LO);
    wire birdie_mid_pos_on = video_active && birdie_on(h_cnt, v_cnt, mid_pos_marker_x, MID_Y_HI);
    wire birdie_mid_neg_on = video_active && birdie_on(h_cnt, v_cnt, mid_neg_marker_x, MID_Y_LO);
    wire birdie_bot_pos_on = video_active && birdie_on(h_cnt, v_cnt, bot_pos_marker_x, BOT_Y_HI);
    wire birdie_bot_neg_on = video_active && birdie_on(h_cnt, v_cnt, bot_neg_marker_x, BOT_Y_LO);
    wire birdie_any_on = birdie_top_pos_on || birdie_top_neg_on ||
                         birdie_mid_pos_on || birdie_mid_neg_on ||
                         birdie_bot_pos_on || birdie_bot_neg_on;

    // Dim reference lines through the center of each third.
    wire center_line_on = video_active && (
        (v_cnt == 10'd120) || (v_cnt == 10'd121) ||
        (v_cnt == 10'd360) || (v_cnt == 10'd361) ||
        (v_cnt == 10'd600) || (v_cnt == 10'd601)
    );

    // Thin divider lines between thirds.
    wire divider_on = video_active && (
        (v_cnt == 10'd240) || (v_cnt == 10'd480)
    );

    // A simple white border around the active 1280x720 image.
    wire border_on = video_active && (
        (h_cnt == 11'd0)    || (h_cnt == 11'd1279) ||
        (v_cnt == 10'd0)    || (v_cnt == 10'd719)
    );

    // Four-stage overlay pipeline for clean TMDS timing.
    // The overlay decision is pipelined to keep the pixel path short enough
    // for 74.25 MHz video timing on the GW1NR-9 device.
    reg        video_active_s1;
    reg        top_trace_on_s1;
    reg        top_sine_on_s1;
    reg        mid_trace_on_s1;
    reg        bot_trace_on_s1;
    reg        birdie_any_on_s1;
    reg        border_on_s1;
    reg        divider_on_s1;
    reg        center_line_on_s1;
    reg [7:0]  red_in_s1;
    reg [7:0]  green_in_s1;
    reg [7:0]  blue_in_s1;

    reg        video_active_s2;
    reg        top_trace_on_s2;
    reg        top_sine_on_s2;
    reg        mid_trace_on_s2;
    reg        bot_trace_on_s2;
    reg        birdie_any_on_s2;
    reg        border_on_s2;
    reg        divider_on_s2;
    reg        center_line_on_s2;
    reg [7:0]  red_in_s2;
    reg [7:0]  green_in_s2;
    reg [7:0]  blue_in_s2;

    reg        video_active_s3;
    reg [3:0]  overlay_sel_s3;
    reg [7:0]  red_in_s3;
    reg [7:0]  green_in_s3;
    reg [7:0]  blue_in_s3;

    reg [7:0] red_next;
    reg [7:0] green_next;
    reg [7:0] blue_next;

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            video_active_s1 <= 1'b0;
            top_trace_on_s1 <= 1'b0;
            top_sine_on_s1 <= 1'b0;
            mid_trace_on_s1 <= 1'b0;
            bot_trace_on_s1 <= 1'b0;
            birdie_any_on_s1 <= 1'b0;
            border_on_s1 <= 1'b0;
            divider_on_s1 <= 1'b0;
            center_line_on_s1 <= 1'b0;
            red_in_s1 <= 8'h00;
            green_in_s1 <= 8'h00;
            blue_in_s1 <= 8'h00;

            video_active_s2 <= 1'b0;
            top_trace_on_s2 <= 1'b0;
            top_sine_on_s2 <= 1'b0;
            mid_trace_on_s2 <= 1'b0;
            bot_trace_on_s2 <= 1'b0;
            birdie_any_on_s2 <= 1'b0;
            border_on_s2 <= 1'b0;
            divider_on_s2 <= 1'b0;
            center_line_on_s2 <= 1'b0;
            red_in_s2 <= 8'h00;
            green_in_s2 <= 8'h00;
            blue_in_s2 <= 8'h00;

            video_active_s3 <= 1'b0;
            overlay_sel_s3 <= 4'd0;
            red_in_s3 <= 8'h00;
            green_in_s3 <= 8'h00;
            blue_in_s3 <= 8'h00;
        end else begin
            // stage 1
            video_active_s1 <= video_active;
            top_trace_on_s1 <= top_trace_on;
            top_sine_on_s1 <= top_sine_on;
            mid_trace_on_s1 <= mid_trace_on;
            bot_trace_on_s1 <= bot_trace_on;
            birdie_any_on_s1 <= birdie_any_on;
            border_on_s1 <= border_on;
            divider_on_s1 <= divider_on;
            center_line_on_s1 <= center_line_on;
            red_in_s1 <= red_in;
            green_in_s1 <= green_in;
            blue_in_s1 <= blue_in;

            // stage 2
            video_active_s2 <= video_active_s1;
            top_trace_on_s2 <= top_trace_on_s1;
            top_sine_on_s2 <= top_sine_on_s1;
            mid_trace_on_s2 <= mid_trace_on_s1;
            bot_trace_on_s2 <= bot_trace_on_s1;
            birdie_any_on_s2 <= birdie_any_on_s1;
            border_on_s2 <= border_on_s1;
            divider_on_s2 <= divider_on_s1;
            center_line_on_s2 <= center_line_on_s1;
            red_in_s2 <= red_in_s1;
            green_in_s2 <= green_in_s1;
            blue_in_s2 <= blue_in_s1;

            // stage 3
            video_active_s3 <= video_active_s2;
            red_in_s3 <= red_in_s2;
            green_in_s3 <= green_in_s2;
            blue_in_s3 <= blue_in_s2;
            if (!video_active_s2)
                overlay_sel_s3 <= 4'd0;
            else if (birdie_any_on_s2)
                overlay_sel_s3 <= 4'd1;
            else if (top_trace_on_s2)
                overlay_sel_s3 <= 4'd2;
            else if (top_sine_on_s2)
                overlay_sel_s3 <= 4'd3;
            else if (mid_trace_on_s2)
                overlay_sel_s3 <= 4'd4;
            else if (bot_trace_on_s2)
                overlay_sel_s3 <= 4'd5;
            else if (border_on_s2)
                overlay_sel_s3 <= 4'd6;
            else if (divider_on_s2)
                overlay_sel_s3 <= 4'd7;
            else if (center_line_on_s2)
                overlay_sel_s3 <= 4'd8;
            else
                overlay_sel_s3 <= 4'd0;
        end
    end

    always @(*) begin
        if (!video_active_s3) begin
            red_next   = 8'h00;
            green_next = 8'h00;
            blue_next  = 8'h00;
        end else begin
            case (overlay_sel_s3)
                4'd1: begin // birdie markers
                    red_next   = 8'hFF;
                    green_next = 8'hFF;
                    blue_next  = 8'hFF;
                end
                4'd2: begin // top square trace: green
                    red_next   = 8'h00;
                    green_next = 8'hFF;
                    blue_next  = 8'h00;
                end
                4'd3: begin // top sine trace: yellow
                    red_next   = 8'hFF;
                    green_next = 8'hFF;
                    blue_next  = 8'h00;
                end
                4'd4: begin // middle trace: cyan
                    red_next   = 8'h00;
                    green_next = 8'hFF;
                    blue_next  = 8'hFF;
                end
                4'd5: begin // bottom trace: magenta
                    red_next   = 8'hFF;
                    green_next = 8'h00;
                    blue_next  = 8'hFF;
                end
                4'd6: begin // border
                    red_next   = 8'hFF;
                    green_next = 8'hFF;
                    blue_next  = 8'hFF;
                end
                4'd7: begin // divider
                    red_next   = 8'h60;
                    green_next = 8'h60;
                    blue_next  = 8'h60;
                end
                4'd8: begin // center line
                    red_next   = 8'h30;
                    green_next = 8'h30;
                    blue_next  = 8'h30;
                end
                default: begin
                    red_next   = red_in_s3;
                    green_next = green_in_s3;
                    blue_next  = blue_in_s3;
                end
            endcase
        end
    end

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            red_out   <= 8'h00;
            green_out <= 8'h00;
            blue_out  <= 8'h00;
        end else begin
            red_out   <= red_next;
            green_out <= green_next;
            blue_out  <= blue_next;
        end
    end

    function [9:0] sine_y_top_from_phase;
        // Small ROM-style sine lookup table for the yellow top waveform.
        // It avoids needing a multiplier or large framebuffer.
        input [7:0] phase;
        begin
            case (phase)
                8'd0: sine_y_top_from_phase = 10'd120;
                8'd1: sine_y_top_from_phase = 10'd118;
                8'd2: sine_y_top_from_phase = 10'd116;
                8'd3: sine_y_top_from_phase = 10'd114;
                8'd4: sine_y_top_from_phase = 10'd112;
                8'd5: sine_y_top_from_phase = 10'd110;
                8'd6: sine_y_top_from_phase = 10'd108;
                8'd7: sine_y_top_from_phase = 10'd106;
                8'd8: sine_y_top_from_phase = 10'd104;
                8'd9: sine_y_top_from_phase = 10'd102;
                8'd10: sine_y_top_from_phase = 10'd101;
                8'd11: sine_y_top_from_phase = 10'd99;
                8'd12: sine_y_top_from_phase = 10'd97;
                8'd13: sine_y_top_from_phase = 10'd95;
                8'd14: sine_y_top_from_phase = 10'd93;
                8'd15: sine_y_top_from_phase = 10'd91;
                8'd16: sine_y_top_from_phase = 10'd89;
                8'd17: sine_y_top_from_phase = 10'd88;
                8'd18: sine_y_top_from_phase = 10'd86;
                8'd19: sine_y_top_from_phase = 10'd84;
                8'd20: sine_y_top_from_phase = 10'd82;
                8'd21: sine_y_top_from_phase = 10'd81;
                8'd22: sine_y_top_from_phase = 10'd79;
                8'd23: sine_y_top_from_phase = 10'd77;
                8'd24: sine_y_top_from_phase = 10'd76;
                8'd25: sine_y_top_from_phase = 10'd74;
                8'd26: sine_y_top_from_phase = 10'd72;
                8'd27: sine_y_top_from_phase = 10'd71;
                8'd28: sine_y_top_from_phase = 10'd69;
                8'd29: sine_y_top_from_phase = 10'd68;
                8'd30: sine_y_top_from_phase = 10'd66;
                8'd31: sine_y_top_from_phase = 10'd65;
                8'd32: sine_y_top_from_phase = 10'd63;
                8'd33: sine_y_top_from_phase = 10'd62;
                8'd34: sine_y_top_from_phase = 10'd61;
                8'd35: sine_y_top_from_phase = 10'd59;
                8'd36: sine_y_top_from_phase = 10'd58;
                8'd37: sine_y_top_from_phase = 10'd57;
                8'd38: sine_y_top_from_phase = 10'd56;
                8'd39: sine_y_top_from_phase = 10'd55;
                8'd40: sine_y_top_from_phase = 10'd53;
                8'd41: sine_y_top_from_phase = 10'd52;
                8'd42: sine_y_top_from_phase = 10'd51;
                8'd43: sine_y_top_from_phase = 10'd50;
                8'd44: sine_y_top_from_phase = 10'd49;
                8'd45: sine_y_top_from_phase = 10'd49;
                8'd46: sine_y_top_from_phase = 10'd48;
                8'd47: sine_y_top_from_phase = 10'd47;
                8'd48: sine_y_top_from_phase = 10'd46;
                8'd49: sine_y_top_from_phase = 10'd45;
                8'd50: sine_y_top_from_phase = 10'd45;
                8'd51: sine_y_top_from_phase = 10'd44;
                8'd52: sine_y_top_from_phase = 10'd43;
                8'd53: sine_y_top_from_phase = 10'd43;
                8'd54: sine_y_top_from_phase = 10'd42;
                8'd55: sine_y_top_from_phase = 10'd42;
                8'd56: sine_y_top_from_phase = 10'd42;
                8'd57: sine_y_top_from_phase = 10'd41;
                8'd58: sine_y_top_from_phase = 10'd41;
                8'd59: sine_y_top_from_phase = 10'd41;
                8'd60: sine_y_top_from_phase = 10'd40;
                8'd61: sine_y_top_from_phase = 10'd40;
                8'd62: sine_y_top_from_phase = 10'd40;
                8'd63: sine_y_top_from_phase = 10'd40;
                8'd64: sine_y_top_from_phase = 10'd40;
                8'd65: sine_y_top_from_phase = 10'd40;
                8'd66: sine_y_top_from_phase = 10'd40;
                8'd67: sine_y_top_from_phase = 10'd40;
                8'd68: sine_y_top_from_phase = 10'd40;
                8'd69: sine_y_top_from_phase = 10'd41;
                8'd70: sine_y_top_from_phase = 10'd41;
                8'd71: sine_y_top_from_phase = 10'd41;
                8'd72: sine_y_top_from_phase = 10'd42;
                8'd73: sine_y_top_from_phase = 10'd42;
                8'd74: sine_y_top_from_phase = 10'd42;
                8'd75: sine_y_top_from_phase = 10'd43;
                8'd76: sine_y_top_from_phase = 10'd43;
                8'd77: sine_y_top_from_phase = 10'd44;
                8'd78: sine_y_top_from_phase = 10'd45;
                8'd79: sine_y_top_from_phase = 10'd45;
                8'd80: sine_y_top_from_phase = 10'd46;
                8'd81: sine_y_top_from_phase = 10'd47;
                8'd82: sine_y_top_from_phase = 10'd48;
                8'd83: sine_y_top_from_phase = 10'd49;
                8'd84: sine_y_top_from_phase = 10'd49;
                8'd85: sine_y_top_from_phase = 10'd50;
                8'd86: sine_y_top_from_phase = 10'd51;
                8'd87: sine_y_top_from_phase = 10'd52;
                8'd88: sine_y_top_from_phase = 10'd53;
                8'd89: sine_y_top_from_phase = 10'd55;
                8'd90: sine_y_top_from_phase = 10'd56;
                8'd91: sine_y_top_from_phase = 10'd57;
                8'd92: sine_y_top_from_phase = 10'd58;
                8'd93: sine_y_top_from_phase = 10'd59;
                8'd94: sine_y_top_from_phase = 10'd61;
                8'd95: sine_y_top_from_phase = 10'd62;
                8'd96: sine_y_top_from_phase = 10'd63;
                8'd97: sine_y_top_from_phase = 10'd65;
                8'd98: sine_y_top_from_phase = 10'd66;
                8'd99: sine_y_top_from_phase = 10'd68;
                8'd100: sine_y_top_from_phase = 10'd69;
                8'd101: sine_y_top_from_phase = 10'd71;
                8'd102: sine_y_top_from_phase = 10'd72;
                8'd103: sine_y_top_from_phase = 10'd74;
                8'd104: sine_y_top_from_phase = 10'd76;
                8'd105: sine_y_top_from_phase = 10'd77;
                8'd106: sine_y_top_from_phase = 10'd79;
                8'd107: sine_y_top_from_phase = 10'd81;
                8'd108: sine_y_top_from_phase = 10'd82;
                8'd109: sine_y_top_from_phase = 10'd84;
                8'd110: sine_y_top_from_phase = 10'd86;
                8'd111: sine_y_top_from_phase = 10'd88;
                8'd112: sine_y_top_from_phase = 10'd89;
                8'd113: sine_y_top_from_phase = 10'd91;
                8'd114: sine_y_top_from_phase = 10'd93;
                8'd115: sine_y_top_from_phase = 10'd95;
                8'd116: sine_y_top_from_phase = 10'd97;
                8'd117: sine_y_top_from_phase = 10'd99;
                8'd118: sine_y_top_from_phase = 10'd101;
                8'd119: sine_y_top_from_phase = 10'd102;
                8'd120: sine_y_top_from_phase = 10'd104;
                8'd121: sine_y_top_from_phase = 10'd106;
                8'd122: sine_y_top_from_phase = 10'd108;
                8'd123: sine_y_top_from_phase = 10'd110;
                8'd124: sine_y_top_from_phase = 10'd112;
                8'd125: sine_y_top_from_phase = 10'd114;
                8'd126: sine_y_top_from_phase = 10'd116;
                8'd127: sine_y_top_from_phase = 10'd118;
                8'd128: sine_y_top_from_phase = 10'd120;
                8'd129: sine_y_top_from_phase = 10'd122;
                8'd130: sine_y_top_from_phase = 10'd124;
                8'd131: sine_y_top_from_phase = 10'd126;
                8'd132: sine_y_top_from_phase = 10'd128;
                8'd133: sine_y_top_from_phase = 10'd130;
                8'd134: sine_y_top_from_phase = 10'd132;
                8'd135: sine_y_top_from_phase = 10'd134;
                8'd136: sine_y_top_from_phase = 10'd136;
                8'd137: sine_y_top_from_phase = 10'd138;
                8'd138: sine_y_top_from_phase = 10'd139;
                8'd139: sine_y_top_from_phase = 10'd141;
                8'd140: sine_y_top_from_phase = 10'd143;
                8'd141: sine_y_top_from_phase = 10'd145;
                8'd142: sine_y_top_from_phase = 10'd147;
                8'd143: sine_y_top_from_phase = 10'd149;
                8'd144: sine_y_top_from_phase = 10'd151;
                8'd145: sine_y_top_from_phase = 10'd152;
                8'd146: sine_y_top_from_phase = 10'd154;
                8'd147: sine_y_top_from_phase = 10'd156;
                8'd148: sine_y_top_from_phase = 10'd158;
                8'd149: sine_y_top_from_phase = 10'd159;
                8'd150: sine_y_top_from_phase = 10'd161;
                8'd151: sine_y_top_from_phase = 10'd163;
                8'd152: sine_y_top_from_phase = 10'd164;
                8'd153: sine_y_top_from_phase = 10'd166;
                8'd154: sine_y_top_from_phase = 10'd168;
                8'd155: sine_y_top_from_phase = 10'd169;
                8'd156: sine_y_top_from_phase = 10'd171;
                8'd157: sine_y_top_from_phase = 10'd172;
                8'd158: sine_y_top_from_phase = 10'd174;
                8'd159: sine_y_top_from_phase = 10'd175;
                8'd160: sine_y_top_from_phase = 10'd177;
                8'd161: sine_y_top_from_phase = 10'd178;
                8'd162: sine_y_top_from_phase = 10'd179;
                8'd163: sine_y_top_from_phase = 10'd181;
                8'd164: sine_y_top_from_phase = 10'd182;
                8'd165: sine_y_top_from_phase = 10'd183;
                8'd166: sine_y_top_from_phase = 10'd184;
                8'd167: sine_y_top_from_phase = 10'd185;
                8'd168: sine_y_top_from_phase = 10'd187;
                8'd169: sine_y_top_from_phase = 10'd188;
                8'd170: sine_y_top_from_phase = 10'd189;
                8'd171: sine_y_top_from_phase = 10'd190;
                8'd172: sine_y_top_from_phase = 10'd191;
                8'd173: sine_y_top_from_phase = 10'd191;
                8'd174: sine_y_top_from_phase = 10'd192;
                8'd175: sine_y_top_from_phase = 10'd193;
                8'd176: sine_y_top_from_phase = 10'd194;
                8'd177: sine_y_top_from_phase = 10'd195;
                8'd178: sine_y_top_from_phase = 10'd195;
                8'd179: sine_y_top_from_phase = 10'd196;
                8'd180: sine_y_top_from_phase = 10'd197;
                8'd181: sine_y_top_from_phase = 10'd197;
                8'd182: sine_y_top_from_phase = 10'd198;
                8'd183: sine_y_top_from_phase = 10'd198;
                8'd184: sine_y_top_from_phase = 10'd198;
                8'd185: sine_y_top_from_phase = 10'd199;
                8'd186: sine_y_top_from_phase = 10'd199;
                8'd187: sine_y_top_from_phase = 10'd199;
                8'd188: sine_y_top_from_phase = 10'd200;
                8'd189: sine_y_top_from_phase = 10'd200;
                8'd190: sine_y_top_from_phase = 10'd200;
                8'd191: sine_y_top_from_phase = 10'd200;
                8'd192: sine_y_top_from_phase = 10'd200;
                8'd193: sine_y_top_from_phase = 10'd200;
                8'd194: sine_y_top_from_phase = 10'd200;
                8'd195: sine_y_top_from_phase = 10'd200;
                8'd196: sine_y_top_from_phase = 10'd200;
                8'd197: sine_y_top_from_phase = 10'd199;
                8'd198: sine_y_top_from_phase = 10'd199;
                8'd199: sine_y_top_from_phase = 10'd199;
                8'd200: sine_y_top_from_phase = 10'd198;
                8'd201: sine_y_top_from_phase = 10'd198;
                8'd202: sine_y_top_from_phase = 10'd198;
                8'd203: sine_y_top_from_phase = 10'd197;
                8'd204: sine_y_top_from_phase = 10'd197;
                8'd205: sine_y_top_from_phase = 10'd196;
                8'd206: sine_y_top_from_phase = 10'd195;
                8'd207: sine_y_top_from_phase = 10'd195;
                8'd208: sine_y_top_from_phase = 10'd194;
                8'd209: sine_y_top_from_phase = 10'd193;
                8'd210: sine_y_top_from_phase = 10'd192;
                8'd211: sine_y_top_from_phase = 10'd191;
                8'd212: sine_y_top_from_phase = 10'd191;
                8'd213: sine_y_top_from_phase = 10'd190;
                8'd214: sine_y_top_from_phase = 10'd189;
                8'd215: sine_y_top_from_phase = 10'd188;
                8'd216: sine_y_top_from_phase = 10'd187;
                8'd217: sine_y_top_from_phase = 10'd185;
                8'd218: sine_y_top_from_phase = 10'd184;
                8'd219: sine_y_top_from_phase = 10'd183;
                8'd220: sine_y_top_from_phase = 10'd182;
                8'd221: sine_y_top_from_phase = 10'd181;
                8'd222: sine_y_top_from_phase = 10'd179;
                8'd223: sine_y_top_from_phase = 10'd178;
                8'd224: sine_y_top_from_phase = 10'd177;
                8'd225: sine_y_top_from_phase = 10'd175;
                8'd226: sine_y_top_from_phase = 10'd174;
                8'd227: sine_y_top_from_phase = 10'd172;
                8'd228: sine_y_top_from_phase = 10'd171;
                8'd229: sine_y_top_from_phase = 10'd169;
                8'd230: sine_y_top_from_phase = 10'd168;
                8'd231: sine_y_top_from_phase = 10'd166;
                8'd232: sine_y_top_from_phase = 10'd164;
                8'd233: sine_y_top_from_phase = 10'd163;
                8'd234: sine_y_top_from_phase = 10'd161;
                8'd235: sine_y_top_from_phase = 10'd159;
                8'd236: sine_y_top_from_phase = 10'd158;
                8'd237: sine_y_top_from_phase = 10'd156;
                8'd238: sine_y_top_from_phase = 10'd154;
                8'd239: sine_y_top_from_phase = 10'd152;
                8'd240: sine_y_top_from_phase = 10'd151;
                8'd241: sine_y_top_from_phase = 10'd149;
                8'd242: sine_y_top_from_phase = 10'd147;
                8'd243: sine_y_top_from_phase = 10'd145;
                8'd244: sine_y_top_from_phase = 10'd143;
                8'd245: sine_y_top_from_phase = 10'd141;
                8'd246: sine_y_top_from_phase = 10'd139;
                8'd247: sine_y_top_from_phase = 10'd138;
                8'd248: sine_y_top_from_phase = 10'd136;
                8'd249: sine_y_top_from_phase = 10'd134;
                8'd250: sine_y_top_from_phase = 10'd132;
                8'd251: sine_y_top_from_phase = 10'd130;
                8'd252: sine_y_top_from_phase = 10'd128;
                8'd253: sine_y_top_from_phase = 10'd126;
                8'd254: sine_y_top_from_phase = 10'd124;
                8'd255: sine_y_top_from_phase = 10'd122;
                default: sine_y_top_from_phase = 10'd120;
            endcase
        end
    endfunction

endmodule
