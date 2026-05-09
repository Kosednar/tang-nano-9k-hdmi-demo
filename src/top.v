// -----------------------------------------------------------------------------
// Tang Nano 9K HDMI Demonstration
//
// Demonstrates a visual comparison between a simple PLL-style timing reference
// and Joseph F. Kosednar's patented phase-engine concept when the displayed duty
// cycle is swept from 40/60 to 60/40.
//
// Coded by ChatGPT with substantial human direction, testing, and correction.
// Date: 5/9/2026
//
// ***************************************************************************
// ****** IMPORTANT: USE GW1NR-9 "DEVICE VERSION C" AS THE TARGET DEVICE *****
// ****** OR GOWIN PROGRAMMER MAY REPORT A DEVICE ID ERROR               *****
// ***************************************************************************
//
// Patent / IP Notice
//
// This HDMI demonstration code is provided only as a Tang Nano 9K HDMI reference
// design and visual display example.
//
// Joseph F. Kosednar's patented AC phase-control / phase-engine intellectual
// property is NOT included in this source code. Any on-screen reference to the
// patent or phase engine is for demonstration and labeling purposes only.
//
// This code does not grant any license, rights, or permission to use, reproduce,
// implement, or derive from the patented phase-engine IP.
//
// Top module: top
//
// This version removes the resetn input pin to avoid a Bank 3 VCCIO conflict.
// Reset is generated internally from the PLL lock signal.
//
// Video path:
//   27 MHz board clock -> rPLL -> 371.25 MHz TMDS 5x clock
//   371.25 MHz / 5 -> 74.25 MHz pixel clock
//   1280x720 @ 60 Hz timing -> Demo -> TMDS encoder -> OSER10 -> HDMI pins
// -----------------------------------------------------------------------------
module top (
    input  wire clk,       // Tang Nano 9K onboard 27 MHz clock, pin 52

    output wire tmds_clk_n,
    output wire tmds_clk_p,
    output wire [2:0] tmds_d_n,
    output wire [2:0] tmds_d_p,

    output wire led1,
    output wire led2,
    output wire led3,
    output wire led4,
    output wire led5,
    output wire led6
);

    wire clk_5x;
    wire pix_clk;
    wire pll_lock;
    wire sys_resetn;

    // clk_5x drives the serializers. pix_clk drives all pixel-domain logic.
    // sys_resetn is released only after the PLL is locked and synchronized.

    // PLL: 27 MHz input -> 371.25 MHz output for 720p60 DVI/HDMI.
    // CLKDIV then divides this by 5 to make a 74.25 MHz pixel clock.
    Gowin_rPLL u_pll (
        .clkin  (clk),
        .clkout (clk_5x),
        .lock   (pll_lock)
    );

    // Divide 5x TMDS clock by 5 to get pixel clock.
    Gowin_CLKDIV u_clkdiv_5 (
        .clkout (pix_clk),
        .hclkin (clk_5x),
        .resetn (pll_lock)
    );

    // No external reset pin. The HDMI core comes out of reset after PLL lock.
    Reset_Sync u_reset_sync (
        .clk       (pix_clk),
        .ext_reset (pll_lock),
        .resetn    (sys_resetn)
    );

    hdmi_bare_colorbars u_hdmi (
        .pix_clk    (pix_clk),
        .clk_5x     (clk_5x),
        .resetn     (sys_resetn),
        .tmds_clk_p (tmds_clk_p),
        .tmds_clk_n (tmds_clk_n),
        .tmds_d_p   (tmds_d_p),
        .tmds_d_n   (tmds_d_n)
    );

    // -------------------------------------------------------------------------
    // Debug LEDs. Tang Nano 9K LEDs are active-low: 0 = LED ON, 1 = LED OFF.
    // -------------------------------------------------------------------------
    reg [24:0] pix_blink  = 25'd0;
    reg [26:0] fast_blink = 27'd0;

    always @(posedge pix_clk or negedge sys_resetn) begin
        if (!sys_resetn)
            pix_blink <= 25'd0;
        else
            pix_blink <= pix_blink + 1'b1;
    end

    always @(posedge clk_5x or negedge pll_lock) begin
        if (!pll_lock)
            fast_blink <= 27'd0;
        else
            fast_blink <= fast_blink + 1'b1;
    end

    assign led1 = ~pll_lock;       // LED ON when PLL locked
    assign led2 = ~sys_resetn;     // LED ON when reset released
    assign led3 = ~pix_blink[24];  // slow blink from pixel clock
    assign led4 = ~fast_blink[26]; // blink from 5x clock
    assign led5 = 1'b1;            // OFF, spare
    assign led6 = 1'b1;            // OFF, spare

endmodule

// -----------------------------------------------------------------------------
// Reset synchronizer. Holds reset low for 16 pixel clocks after PLL lock.
// -----------------------------------------------------------------------------
module Reset_Sync (
    input  wire clk,
    input  wire ext_reset,
    output wire resetn
);
    reg [3:0] reset_cnt = 4'd0;

    always @(posedge clk or negedge ext_reset) begin
        if (!ext_reset)
            reset_cnt <= 4'd0;
        else if (!resetn)
            reset_cnt <= reset_cnt + 1'b1;
    end

    assign resetn = &reset_cnt;
endmodule
