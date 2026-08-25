#!/usr/bin/env bash
set -euo pipefail

# Converts rtl/*.sv to plain Verilog via sv2v, since SymbiYosys's Yosys
# frontend can't parse the SV constructs the RTL uses. checks.cfg reads
# this output, never rtl/*.sv directly.

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

# RVFI_OUTPUTS etc come from rvfi_macros.vh; defines mirror checks.cfg
cat > "$BUILD_DIR/rvfi_defines.vh" <<'EOF'
`define RISCV_FORMAL
`define RISCV_FORMAL_NRET 1
`define RISCV_FORMAL_XLEN 32
`define RISCV_FORMAL_ILEN 32
`define RISCV_FORMAL_ALIGNED_MEM
`define RISCV_FORMAL_MEM_FAULT
`include "rvfi_macros.vh"
EOF

sources=()
for f in "${RTL_FILES[@]}"; do
    sources+=("$REPO_ROOT/rtl/$f")
done
sources+=("$SCRIPT_DIR/rvfi_wrapper.sv")

sv2v -I "$SCRIPT_DIR/riscv-formal/checks" \
     --write="$BUILD_DIR" \
     "$BUILD_DIR/rvfi_defines.vh" \
     "${sources[@]}"

echo "formal/build.sh: wrote plain-Verilog sources to $BUILD_DIR"
