#!/usr/bin/env bash
set -euo pipefail

# Converts rtl/*.sv to plain Verilog via sv2v, since SymbiYosys's Yosys
# frontend can't parse the SV constructs the RTL uses.
# rvfi_wrapper.sv is NOT included: sv2v silently drops assume()/assert().
# checks.cfg reads it directly as SV instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

RTL_FILES=(
    core_pkg.sv
    alu.sv
    alu_dec.sv
    branch_logic.sv
    controller.sv
    datapath.sv
    fault_ctrl.sv
    imm_gen.sv
    lsu.sv
    main_dec.sv
    reg_file.sv
    stall_ctrl.sv
    rv32i_core.sv
)

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

sources=()
for f in "${RTL_FILES[@]}"; do
    sources+=("$REPO_ROOT/rtl/$f")
done

sv2v --write="$BUILD_DIR" "${sources[@]}"

echo "formal/build.sh: wrote plain-Verilog sources to $BUILD_DIR"
