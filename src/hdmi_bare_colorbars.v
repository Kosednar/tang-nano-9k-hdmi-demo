// -----------------------------------------------------------------------------
// Tang Nano 9K - HDMI/DVI 720p60 text-buffer demo
//
// Based on the known-working 720p60 color-bar project:
//   74.25 MHz pixel clock
//   371.25 MHz TMDS serializer clock
//   explicit OSER10 serializers
//   explicit ELVDS_OBUF differential outputs
//
// This version replaces color bars with an internal-BSRAM text/tile framebuffer.
// -----------------------------------------------------------------------------

module hdmi_bare_colorbars (
    input  wire pix_clk,     // 74.25 MHz pixel clock
    input  wire clk_5x,      // 371.25 MHz serializer clock
    input  wire resetn,

    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);

    // 1280x720 @ 60 Hz timing, CTA/HDTV-style 720p60.
    localparam [10:0] H_ACTIVE = 11'd1280;
    localparam [10:0] H_FRONT  = 11'd110;
    localparam [10:0] H_SYNC   = 11'd40;
    localparam [10:0] H_BACK   = 11'd220;
    localparam [10:0] H_TOTAL  = 11'd1650;

    localparam [9:0] V_ACTIVE = 10'd720;
    localparam [9:0] V_FRONT  = 10'd5;
    localparam [9:0] V_SYNC   = 10'd5;
    localparam [9:0] V_BACK   = 10'd20;
    localparam [9:0] V_TOTAL  = 10'd750;

    reg [10:0] h_cnt = 11'd0;
    reg [9:0]  v_cnt = 10'd0;

    // h_cnt and v_cnt generate the complete video raster, including blanking.
    // During active video, h_cnt is 0..1279 and v_cnt is 0..719.

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            h_cnt <= 11'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1'b1) begin
                h_cnt <= 11'd0;
                if (v_cnt == V_TOTAL - 1'b1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    wire video_active = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    // video_active is the DVI/HDMI data-enable signal. Pixels are sent only
    // during this region; during blanking the blue channel sends sync codes.

    wire hsync_pulse = (h_cnt >= (H_ACTIVE + H_FRONT)) &&
                       (h_cnt <  (H_ACTIVE + H_FRONT + H_SYNC));

    wire vsync_pulse = (v_cnt >= (V_ACTIVE + V_FRONT)) &&
                       (v_cnt <  (V_ACTIVE + V_FRONT + V_SYNC));

    // 720p60 uses positive sync: sync signal is 1 during the pulse.
    wire hsync = hsync_pulse;
    wire vsync = vsync_pulse;

    // -------------------------------------------------------------------------
    // Internal-RAM display buffer.
    // Write port is present but tied off here. Later you can connect it to a
    // UART/SPI loader, a soft CPU, or your own logic.
    // -------------------------------------------------------------------------
    wire [7:0] text_red;
    wire [7:0] text_green;
    wire [7:0] text_blue;

    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    text_framebuffer_720p u_text_fb (
        .pix_clk      (pix_clk),
        .resetn       (resetn),
        .video_active (video_active),
        .h_cnt        (h_cnt),
        .v_cnt        (v_cnt),
        .wr_en        (1'b0),
        .wr_addr      (12'd0),
        .wr_data      (16'd0),
        .red          (text_red),
        .green        (text_green),
        .blue         (text_blue)
    );

    // -------------------------------------------------------------------------
    // Procedural sine-wave overlay. This draws the wave without a bitmap
    // framebuffer, so it uses very little RAM.
    // -------------------------------------------------------------------------
    sine_wave_overlay_720p u_sine_overlay (
        .pix_clk      (pix_clk),
        .resetn       (resetn),
        .video_active (video_active),
        .h_cnt        (h_cnt),
        .v_cnt        (v_cnt),
        .red_in       (text_red),
        .green_in     (text_green),
        .blue_in      (text_blue),
        .red_out      (red),
        .green_out    (green),
        .blue_out     (blue)
    );

    // -------------------------------------------------------------------------
    // TMDS encode.
    // HDMI/DVI data lane 0 carries blue and H/V sync control during blanking.
    // Data lane 1 carries green. Data lane 2 carries red.
    // -------------------------------------------------------------------------
    wire [9:0] tmds_blue;
    wire [9:0] tmds_green;
    wire [9:0] tmds_red;

    // Each 8-bit RGB value is converted to a 10-bit TMDS word once per pixel.

    tmds_encoder enc_blue (
        .clk    (pix_clk),
        .resetn (resetn),
        .de     (video_active),
        .ctrl   ({vsync, hsync}),
        .din    (blue),
        .dout   (tmds_blue)
    );

    tmds_encoder enc_green (
        .clk    (pix_clk),
        .resetn (resetn),
        .de     (video_active),
        .ctrl   (2'b00),
        .din    (green),
        .dout   (tmds_green)
    );

    tmds_encoder enc_red (
        .clk    (pix_clk),
        .resetn (resetn),
        .de     (video_active),
        .ctrl   (2'b00),
        .din    (red),
        .dout   (tmds_red)
    );

    // -------------------------------------------------------------------------
    // Explicit 10:1 serializers. D0 is transmitted first.
    // -------------------------------------------------------------------------
    wire tmds_blue_serial;
    wire tmds_green_serial;
    wire tmds_red_serial;

    // The three OSER10 blocks shift the 10-bit TMDS words out at 10 bits/pixel.

    OSER10 ser_blue (
        .Q     (tmds_blue_serial),
        .D0    (tmds_blue[0]),
        .D1    (tmds_blue[1]),
        .D2    (tmds_blue[2]),
        .D3    (tmds_blue[3]),
        .D4    (tmds_blue[4]),
        .D5    (tmds_blue[5]),
        .D6    (tmds_blue[6]),
        .D7    (tmds_blue[7]),
        .D8    (tmds_blue[8]),
        .D9    (tmds_blue[9]),
        .PCLK  (pix_clk),
        .FCLK  (clk_5x),
        .RESET (~resetn)
    );

    OSER10 ser_green (
        .Q     (tmds_green_serial),
        .D0    (tmds_green[0]),
        .D1    (tmds_green[1]),
        .D2    (tmds_green[2]),
        .D3    (tmds_green[3]),
        .D4    (tmds_green[4]),
        .D5    (tmds_green[5]),
        .D6    (tmds_green[6]),
        .D7    (tmds_green[7]),
        .D8    (tmds_green[8]),
        .D9    (tmds_green[9]),
        .PCLK  (pix_clk),
        .FCLK  (clk_5x),
        .RESET (~resetn)
    );

    OSER10 ser_red (
        .Q     (tmds_red_serial),
        .D0    (tmds_red[0]),
        .D1    (tmds_red[1]),
        .D2    (tmds_red[2]),
        .D3    (tmds_red[3]),
        .D4    (tmds_red[4]),
        .D5    (tmds_red[5]),
        .D6    (tmds_red[6]),
        .D7    (tmds_red[7]),
        .D8    (tmds_red[8]),
        .D9    (tmds_red[9]),
        .PCLK  (pix_clk),
        .FCLK  (clk_5x),
        .RESET (~resetn)
    );

    // -------------------------------------------------------------------------
    // True differential output buffers. Do not manually invert N pins.
    // -------------------------------------------------------------------------
    ELVDS_OBUF obuf_tmds_clk (
        .I  (pix_clk),
        .O  (tmds_clk_p),
        .OB (tmds_clk_n)
    );

    ELVDS_OBUF obuf_tmds_d0 (
        .I  (tmds_blue_serial),
        .O  (tmds_d_p[0]),
        .OB (tmds_d_n[0])
    );

    ELVDS_OBUF obuf_tmds_d1 (
        .I  (tmds_green_serial),
        .O  (tmds_d_p[1]),
        .OB (tmds_d_n[1])
    );

    ELVDS_OBUF obuf_tmds_d2 (
        .I  (tmds_red_serial),
        .O  (tmds_d_p[2]),
        .OB (tmds_d_n[2])
    );

endmodule
