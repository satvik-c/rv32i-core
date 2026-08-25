#!/usr/bin/env python3
"""Usage: coverage_union.py <metrics.db> [<metrics.db> ...]

Combines functional coverage across many DSim metrics.db files. dcmerge+dcreport
segfaults on merged databases, and DSim's own per-test aggWeightSummary table only
stores a pre-reduced hit-fraction per coverpoint (den is always 1) - no per-bin
identity - so an exact union isn't recoverable from this data. Instead this reports
a range per coverpoint/cross:
  LOWER = max fraction seen in any single db (guaranteed covered)
  UPPER = sum of fractions capped at 100% (best case, if no test's hits overlap)
"""
import sqlite3
import sys


def load(db_path):
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    cur.execute("SELECT cgHash, name FROM covergroups")
    cg_name = dict(cur.fetchall())

    cur.execute("SELECT cpHash, cgHash, name FROM coverpoints")
    items = {}
    for cp_hash, cg_hash, name in cur.fetchall():
        if cg_hash in cg_name:
            items[cp_hash] = f"{cg_name[cg_hash]}.{name}"
    for cg_hash, name in cg_name.items():
        items[cg_hash] = f"{name}.TOTAL"

    cur.execute("SELECT itemHash, num FROM aggWeightSummary")
    result = {}
    for item_hash, num in cur.fetchall():
        key = items.get(item_hash)
        if key is not None:
            result[key] = num
    con.close()
    return result


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    lower = {}
    upper = {}
    for db_path in sys.argv[1:]:
        for key, frac in load(db_path).items():
            lower[key] = max(lower.get(key, 0.0), frac)
            upper[key] = min(1.0, upper.get(key, 0.0) + frac)

    print(f"{'COVERPOINT/CROSS':<40} {'LOWER %':>8} {'UPPER %':>8}")
    print("-" * 58)
    for key in sorted(lower, key=lambda k: lower[k]):
        print(f"{key:<40} {lower[key]*100:8.2f} {upper[key]*100:8.2f}")


if __name__ == "__main__":
    main()
