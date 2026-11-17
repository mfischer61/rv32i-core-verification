# cocotb + pyuvm runner for my RV32I core.
#   make                      # Xcelium on the SJ server, both tests
#   make TESTCASE=RandomTest SEED=1234 NUM_PROGRAMS=200
#   make SIM=icarus           # if you have an SV-capable open-source sim
#
# RTL_DIR must point at a full onboarding checkout (my cpu/ RTL plus the club's
# chip_top, memory_controller, sram_wrapper, and SRAM model, which are not in
# this public repo).
RTL_DIR       ?= $(HOME)/Silicon-Jackets-Onboarding/src/verilog
SIM           ?= xcelium
TOPLEVEL_LANG  = verilog
TOPLEVEL       = chip_top
MODULE         = test_rv32_pyuvm

VERILOG_SOURCES = $(RTL_DIR)/cpu/cpu_pkg.sv \
                  $(RTL_DIR)/cpu/alu.sv \
                  $(RTL_DIR)/cpu/decode.sv \
                  $(RTL_DIR)/cpu/fetch.sv \
                  $(RTL_DIR)/cpu/reg_file.sv \
                  $(RTL_DIR)/cpu/cpu_top.sv \
                  $(RTL_DIR)/CF_SRAM_1024x32.tt_180V_25C.v \
                  $(RTL_DIR)/sram_wrapper.sv \
                  $(RTL_DIR)/memory_controller.sv \
                  $(RTL_DIR)/chip_top.sv

export SEED NUM_PROGRAMS

include $(shell cocotb-config --makefiles)/Makefile.sim
