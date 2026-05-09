# 27 MHz input clock on the Tang Nano 9K board.
# The Gowin PLL generates the 371.25 MHz serializer clock from this input.
create_clock -name clk -period 37.037 [get_ports {clk}]
