vlib work
vlib riviera

vlib riviera/xil_defaultlib

vmap xil_defaultlib riviera/xil_defaultlib

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../ipstatic" \
"../../../../thinpad_top.srcs/sources_1/ip/pll_example/pll_example_clk_wiz.v" \
"../../../../thinpad_top.srcs/sources_1/ip/pll_example/pll_example.v" \


vlog -work xil_defaultlib \
"glbl.v"

