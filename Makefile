TOP      = tb_axis_bcd_filter
RTL_DIR  = ./rtl
SIM_DIR  = ./sim

SRCS     = $(RTL_DIR)/axis_bcd_filter.sv \
		   $(RTL_DIR)/axis_if.sv \
           $(SIM_DIR)/tb_axis_bcd_filter.sv

SIM_BIN  = $(TOP).vvp
WAVE     = $(TOP).vcd

.PHONY: all sim wave clean

all: sim

sim: 
	vlib work
	vlog -sv $(SRCS)
	vopt +acc $(TOP) -o $(TOP)_opt
	vsim -c $(TOP)_opt -do "run -all; quit"

gui:
	vlib work
	vlog -sv $(SRCS)
	vopt +acc $(TOP) -o top_opt
	vsim top_opt -do "add wave -r /*; run -all"

clean:
	rm -f $(SIM_BIN) $(WAVE)
	rm -rf work
