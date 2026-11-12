## Timing constraints for single_port_ram and dual_port_ram
## Target part: xc7a35tcpg236-1 (Artix-7)
##
## Clock period used for the reported results:
##   single_port_ram : 10.000 ns (100 MHz) -> met, WNS +0.346 ns
##   dual_port_ram   : 12.500 ns ( 80 MHz) -> met, WNS +0.438 ns
##                     (fails at 10.000 ns by 2.059 ns, see README)
create_clock -period 12.500 -name clk [get_ports clk]

## I/O delays of 0 ns: only the delay inside the FPGA is measured.
## Wildcards match both designs (en/en_a/en_b, dout/dout_a/dout_b ...).
set_input_delay  -clock clk 0.0 [get_ports {en* we* addr* din*}]
set_output_delay -clock clk 0.0 [get_ports {dout*}]
