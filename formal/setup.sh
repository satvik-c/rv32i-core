#!/usr/bin/env bash
set -euo pipefail

# Idempotent riscv-formal harness setup. Run before build.sh + genchecks.py.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RF_DIR="$SCRIPT_DIR/riscv-formal"
CORE_DIR="$RF_DIR/cores/rv32i-core"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
git submodule update --init --recursive -- formal/riscv-formal

# Compat patch: modern Yosys wants `rand const reg`, not the vendored
# `const rand reg`. Applied to the submodule's working tree, never committed.
MACROS_VH="$RF_DIR/checks/rvfi_macros.vh"
if grep -q '^`define rvformal_const_rand_reg const rand reg$' "$MACROS_VH"; then
    sed -i 's/^`define rvformal_const_rand_reg const rand reg$/`define rvformal_const_rand_reg rand const reg/' "$MACROS_VH"
    echo "formal/setup.sh: patched rvfi_macros.vh (const rand reg -> rand const reg)"
fi

# genchecks.py expects checks.cfg at cores/<name>/checks.cfg; symlink it in
mkdir -p "$CORE_DIR"
ln -sf ../../../checks.cfg "$CORE_DIR/checks.cfg"

echo "formal/setup.sh: ready. Next: formal/build.sh, then genchecks.py from $CORE_DIR"
