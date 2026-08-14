RISCV_GCC     := riscv64-unknown-elf-gcc
RISCV_OBJCOPY := riscv64-unknown-elf-objcopy
SPIKE         := spike
DSIM          := dsim
DCREPORT	  := dcreport -out_dir reports metrics.db

MARCH := rv32i
MABI  := ilp32
BUILD := build

SPIKE_MEM := -m0x7f000000:0x01000000 -m0x80000000:0x00300000

TEST ?= test_smoke

.PHONY: all clean run_test test_smoke

all: test_smoke

$(BUILD):
	mkdir -p $(BUILD)

# Build any .s test into .elf
$(BUILD)/%.elf: sw/tests/%.s sw/link.ld | $(BUILD)
	$(RISCV_GCC) -march=$(MARCH) -mabi=$(MABI) -nostdlib -nostartfiles -T sw/link.ld -o $@ $<

# Convert any .elf to .hex
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(RISCV_OBJCOPY) -O verilog --verilog-data-width=4 $< $@

# Generate Spike log for any .elf
$(BUILD)/%.spike.log: $(BUILD)/%.elf
	$(SPIKE) --log-commits --isa=$(MARCH) $(SPIKE_MEM) --instructions=100000 --log=$@ $< || true

# Run DSim on any test passed via TEST=<name>
run_test: $(BUILD)/$(TEST).hex $(BUILD)/$(TEST).spike.log
	$(DSIM) -f filelist.f +incdir+dv/env dv/tb_top.sv -top tb_top -code-cov a \
		+HEX_FILE=$(BUILD)/$(TEST).hex \
		+SPIKE_LOG=$(BUILD)/$(TEST).spike.log
	$(DCREPORT)

test_smoke:
	@$(MAKE) run_test TEST=test_smoke

clean:
	rm -rf $(BUILD) dsim_work dsim.log image.so metrics.db dsim.env *.fst *.vcd *.wdb
