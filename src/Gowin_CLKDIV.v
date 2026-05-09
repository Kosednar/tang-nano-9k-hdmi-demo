// -----------------------------------------------------------------------------
// Clock divider wrapper for the Tang Nano 9K HDMI demo.
// Gowin's OSER10 serializer needs a 5x TMDS clock and a pixel clock.
// This primitive divides the 371.25 MHz PLL clock by 5 to make 74.25 MHz.
// -----------------------------------------------------------------------------
// Gowin CLKDIV wrapper: divide high-speed pixel clock by 5.

module Gowin_CLKDIV (clkout, hclkin, resetn);

output clkout;
input  hclkin;
input  resetn;

wire gw_gnd;
assign gw_gnd = 1'b0;

CLKDIV clkdiv_inst (
    .CLKOUT(clkout),
    .HCLKIN(hclkin),
    .RESETN(resetn),
    .CALIB(gw_gnd)
);

defparam clkdiv_inst.DIV_MODE = "5";
defparam clkdiv_inst.GSREN = "false";

endmodule
