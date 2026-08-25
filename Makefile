SHELL := bash

RISCV_GCC     := riscv64-unknown-elf-gcc
RISCV_OBJCOPY := riscv64-unknown-elf-objcopy
SPIKE         := spike
DSIM          := dsim
DCMERGE       := dcmerge
DCREPORT      := dcreport -out_dir

MARCH := rv32i
MABI  := ilp32
BUILD := build
REPORTS := reports

SPIKE_MEM := -m0x7f000000:0x01000000 -m0x80000000:0x00300000

TEST ?= test_smoke
RANDOMIZE ?= 0
NUM_PROGS ?= 500
NUM_INSTR ?= 2000

ALL_TESTS := $(basename $(notdir $(wildcard sw/tests/*.s sw/tests/*.c)))

FORMAL_DIR := formal/riscv-formal/cores/rv32i-core

.PHONY: all clean run_test test_smoke test_directed_isa test_control_flow test_memory_access test_compiled_c test_memory_stall test_random_program regression formal coverage_signoff

all: test_smoke

$(BUILD):
	mkdir -p $(BUILD)

# Build any .s test into .elf
$(BUILD)/%.elf: sw/tests/%.s sw/link.ld | $(BUILD)
	$(RISCV_GCC) -march=$(MARCH) -mabi=$(MABI) -nostdlib -nostartfiles -T sw/link.ld -o $@ $<

# Build any .c test into .elf, linked against the shared C startup.
$(BUILD)/%.elf: sw/tests/%.c sw/crt0.s sw/link.ld | $(BUILD)
	$(RISCV_GCC) -march=$(MARCH) -mabi=$(MABI) -nostdlib -nostartfiles -ffreestanding \
		-msmall-data-limit=0 -T sw/link.ld -o $@ sw/crt0.s $<  # crt0 never sets gp, so disable gp-relative accesses

# Build a generated random program into .elf
$(BUILD)/random/%.elf: $(BUILD)/random/%.s sw/link.ld
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
		-cov-db $(BUILD)/$(TEST).$(RANDOMIZE).metrics.db \
		+HEX_FILE=$(BUILD)/$(TEST).hex \
		+SPIKE_LOG=$(BUILD)/$(TEST).spike.log \
		$(if $(filter 1,$(RANDOMIZE)),+RANDOMIZE_MEM_TIMING)

test_smoke:
	@$(MAKE) run_test TEST=test_smoke
	$(DCREPORT) $(REPORTS)/test_smoke.$(RANDOMIZE) $(BUILD)/test_smoke.$(RANDOMIZE).metrics.db

test_directed_isa:
	@$(MAKE) run_test TEST=test_directed_isa
	$(DCREPORT) $(REPORTS)/test_directed_isa.$(RANDOMIZE) $(BUILD)/test_directed_isa.$(RANDOMIZE).metrics.db

test_control_flow:
	@$(MAKE) run_test TEST=test_control_flow
	$(DCREPORT) $(REPORTS)/test_control_flow.$(RANDOMIZE) $(BUILD)/test_control_flow.$(RANDOMIZE).metrics.db

test_memory_access:
	@$(MAKE) run_test TEST=test_memory_access
	$(DCREPORT) $(REPORTS)/test_memory_access.$(RANDOMIZE) $(BUILD)/test_memory_access.$(RANDOMIZE).metrics.db

test_compiled_c:
	@$(MAKE) run_test TEST=test_compiled_c
	$(DCREPORT) $(REPORTS)/test_compiled_c.$(RANDOMIZE) $(BUILD)/test_compiled_c.$(RANDOMIZE).metrics.db

RANDOM_DIR := $(BUILD)/random
RANDOM_LOGS := $(BUILD)/random_logs
RANDOM_REPORTS := $(REPORTS)/random

test_random_program:
	@mkdir -p $(RANDOM_DIR) $(RANDOM_LOGS) $(RANDOM_REPORTS)
	@rm -f $(RANDOM_LOGS)/*.log
	@fail=0; \
	for s in $$(seq 1 $(NUM_PROGS)); do \
		echo "=== random/prog_$$s (seed=$$s, count=$(NUM_INSTR)) ==="; \
		python3 scripts/gen_random_program.py --seed $$s --count $(NUM_INSTR) -o $(RANDOM_DIR)/prog_$$s.s; \
		$(MAKE) run_test TEST=random/prog_$$s RANDOMIZE=1 > $(RANDOM_LOGS)/prog_$$s.log 2>&1; \
		if [ $$? -ne 0 ]; then fail=1; fi; \
		$(DCREPORT) $(RANDOM_REPORTS)/prog_$$s $(RANDOM_DIR)/prog_$$s.1.metrics.db > /dev/null 2>&1 || true; \
	done; \
	scripts/regression_summary.sh $(RANDOM_LOGS) $(RANDOM_REPORTS) || fail=1; \
	scripts/coverage_union.py $(RANDOM_DIR)/*.metrics.db; \
	exit $$fail

test_memory_stall:
	@for t in $(ALL_TESTS); do \
		echo "=== $$t (RANDOMIZE=1) ==="; \
		$(MAKE) run_test TEST=$$t RANDOMIZE=1 || exit 1; \
	done
	$(DCMERGE) $(addprefix $(BUILD)/,$(addsuffix .1.metrics.db,$(ALL_TESTS))) -out_db $(BUILD)/test_memory_stall.metrics.db
	@$(DCREPORT) $(REPORTS)/test_memory_stall $(BUILD)/test_memory_stall.metrics.db || true

REGRESSION_LOGS := $(BUILD)/regression_logs

regression:
	@mkdir -p $(REGRESSION_LOGS)
	@rm -f $(REGRESSION_LOGS)/*.log
	@fail=0; \
	for t in $(ALL_TESTS); do \
		for r in 0 1; do \
			echo "=== $$t RANDOMIZE=$$r ==="; \
			$(MAKE) run_test TEST=$$t RANDOMIZE=$$r > $(REGRESSION_LOGS)/$$t.$$r.log 2>&1; \
			if [ $$? -ne 0 ]; then fail=1; fi; \
			$(DCREPORT) $(REPORTS)/$$t.$$r $(BUILD)/$$t.$$r.metrics.db > /dev/null 2>&1 || true; \
		done; \
	done; \
	echo ""; \
	scripts/regression_summary.sh $(REGRESSION_LOGS) $(REPORTS) || fail=1; \
	echo ""; \
	scripts/coverage_union.py $(BUILD)/*.metrics.db; \
	exit $$fail

# Unions regression + test_random_program metrics; run both first
coverage_signoff:
	scripts/coverage_union.py $(BUILD)/*.metrics.db $(RANDOM_DIR)/*.metrics.db

formal:
	@./formal/setup.sh
	@./formal/build.sh
	@cd $(FORMAL_DIR) && rm -rf checks && python3 ../../checks/genchecks.py
	@fail=0; \
	cd $(FORMAL_DIR)/checks && \
	for f in *.sby; do \
		name=$${f%.sby}; \
		echo "=== $$name ==="; \
		sby -f "$$f" > "$$name.runlog" 2>&1 & \
		while [ "$$(jobs -r | wc -l)" -ge 8 ]; do wait -n; done; \
	done; \
	wait; \
	for f in *.sby; do \
		name=$${f%.sby}; \
		status=$$(cat "$$name/status" 2>/dev/null || echo "NO_STATUS"); \
		echo "$$name: $$status"; \
		echo "$$status" | grep -q "^PASS" || fail=1; \
	done; \
	exit $$fail

clean:
	rm -rf $(BUILD) $(REPORTS) dsim_work dsim.log image.so metrics.db dsim.env *.fst *.vcd *.wdb
