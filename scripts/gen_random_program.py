#!/usr/bin/env python3
# Generates a seeded, random RV32I .s program for co-simulation regression.
# x30/x31 are reserved as scratch-memory/jump-target pointers; all mem access
# stays in a pre-zeroed scratch region and all jumps are forward-only, so the
# program never faults or hangs without needing to track generator state.

import argparse
import random

REG_POOL = [f"x{i}" for i in range(1, 30)]
SCRATCH_REG = "x30"
JUMP_REG = "x31"
SCRATCH_BASE = 0x80101000
SCRATCH_WORDS = 64
JUMP_WINDOW = 16

ALU_R_OPS = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
ALU_I_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SHIFT_I_OPS = ["slli", "srli", "srai"]
LOAD_OPS = {"lb": 1, "lh": 2, "lw": 4, "lbu": 1, "lhu": 2}
STORE_OPS = {"sb": 1, "sh": 2, "sw": 4}
BRANCH_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]

CATEGORIES = ["alu_r", "alu_i", "shift_i", "load", "store", "lui", "auipc"]
CATEGORY_WEIGHTS = [15, 15, 8, 15, 15, 8, 8]
JUMP_CATEGORIES = ["branch", "jal", "jalr"]
JUMP_WEIGHTS = [6, 5, 5]


def reg(rng):
    return rng.choice(REG_POOL)


def aligned_offset(rng, width):
    step = width if width > 1 else 1
    return rng.randrange(0, SCRATCH_WORDS * 4 - width + 1, step)


def gen_instr(rng, idx, total):
    cats, weights = list(CATEGORIES), list(CATEGORY_WEIGHTS)
    if idx < total - 1:
        cats += JUMP_CATEGORIES
        weights += JUMP_WEIGHTS
    cat = rng.choices(cats, weights=weights)[0]
    label = f"L{idx}:"

    if cat == "alu_r":
        op, rd, rs1, rs2 = rng.choice(ALU_R_OPS), reg(rng), reg(rng), reg(rng)
        return [f"{label} {op} {rd}, {rs1}, {rs2}"]
    if cat == "alu_i":
        op, rd, rs1 = rng.choice(ALU_I_OPS), reg(rng), reg(rng)
        return [f"{label} {op} {rd}, {rs1}, {rng.randint(-2048, 2047)}"]
    if cat == "shift_i":
        op, rd, rs1 = rng.choice(SHIFT_I_OPS), reg(rng), reg(rng)
        return [f"{label} {op} {rd}, {rs1}, {rng.randint(0, 31)}"]
    if cat == "load":
        op, width = rng.choice(list(LOAD_OPS.items()))
        return [f"{label} {op} {reg(rng)}, {aligned_offset(rng, width)}({SCRATCH_REG})"]
    if cat == "store":
        op, width = rng.choice(list(STORE_OPS.items()))
        return [f"{label} {op} {reg(rng)}, {aligned_offset(rng, width)}({SCRATCH_REG})"]
    if cat == "lui":
        return [f"{label} lui {reg(rng)}, {rng.randint(0, 0xFFFFF)}"]
    if cat == "auipc":
        return [f"{label} auipc {reg(rng)}, {rng.randint(0, 0xFFFFF)}"]
    if cat == "branch":
        op = rng.choice(BRANCH_OPS)
        target = rng.randint(idx + 1, min(idx + JUMP_WINDOW, total - 1))
        return [f"{label} {op} {reg(rng)}, {reg(rng)}, L{target}"]
    if cat == "jal":
        target = rng.randint(idx + 1, min(idx + JUMP_WINDOW, total - 1))
        return [f"{label} jal x0, L{target}"]
    if cat == "jalr":
        target = rng.randint(idx + 1, min(idx + JUMP_WINDOW, total - 1))
        return [f"{label} la {JUMP_REG}, L{target}", f"    jalr x0, 0({JUMP_REG})"]
    raise AssertionError(cat)


def generate(seed, count):
    rng = random.Random(seed)
    lines = [".section .text.init", ".globl _start", "", "_start:"]
    for r in REG_POOL:
        lines.append(f"    li {r}, 0")
    lines.append(f"    li {SCRATCH_REG}, {SCRATCH_BASE}")
    lines.append(f"    li {JUMP_REG}, 0")
    for i in range(SCRATCH_WORDS):
        lines.append(f"    sw zero, {4 * i}({SCRATCH_REG})")

    for idx in range(count):
        lines.extend(gen_instr(rng, idx, count))

    lines.append(f"L{count}:")
    # SIM_EXIT: store bit0=1 to 0x10000000 to terminate testbench
    lines.append("    li t0, 0x10000000")
    lines.append("    addi a0, x0, 1")
    lines.append("    sw a0, 0(t0)")
    lines.append("    sw zero, 4(t0)")
    lines.append("done: j done")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--count", type=int, default=2000)
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()
    with open(args.out, "w") as f:
        f.write(generate(args.seed, args.count))
