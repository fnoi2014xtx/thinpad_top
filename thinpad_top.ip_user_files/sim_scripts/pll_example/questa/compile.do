vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xil_defaultlib

vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xil_defaultlib -64 "+incdir+../../../ipstatic" \
"../../../../thinpad_top.srcs/sources_1/ip/pll_example/pll_example_clk_wiz.v" \
"../../../../thinpad_top.srcs/sources_1/ip/pll_example/pll_example.v" \


vlog -work xil_defaultlib \
"glbl.v"

