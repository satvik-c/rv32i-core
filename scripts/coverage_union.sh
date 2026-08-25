#!/usr/bin/env bash
# Usage: coverage_union.sh <reports_dir> [<reports_dir> ...]
# Per-coverpoint/cross MAX % across all reports -- a lower bound on true
# union coverage, since dcreport has no per-bin data to add non-overlapping hits.
set -euo pipefail

for REPORTS_DIR in "$@"; do
for d in "$REPORTS_DIR"/*/; do
    idx="${d}index.html"
    [ -f "$idx" ] || continue
    for group in rvfi_cov_u mem_timing_cov_u; do
        page=$(grep -oE "${group}</td><td>\[<a href=\"[a-zA-Z0-9_]+\.html" "$idx" 2>/dev/null \
               | grep -oE '[a-zA-Z0-9_]+\.html$' || true)
        [ -n "$page" ] && [ -f "$d$page" ] || continue

        grep -oE '<tr><th>covergroup</th><th>[0-9.]+</th></tr>' "$d$page" 2>/dev/null \
            | grep -oE '[0-9.]+' | sed "s/^/${group}.TOTAL /"

        grep -oE '<tr><td>[a-zA-Z0-9_]+</td><td>[0-9.]+</td></tr>' "$d$page" 2>/dev/null \
            | sed -E "s#<tr><td>([a-zA-Z0-9_]+)</td><td>([0-9.]+)</td></tr>#${group}.\1 \2#"
    done
done
done | awk '
{
    if (!($1 in maxv) || $2+0 > maxv[$1]+0) maxv[$1] = $2
}
END {
    printf "%-40s %s\n", "COVERPOINT/CROSS", "MAX % (union lower bound)"
    print "-----------------------------------------------------------------"
    for (k in maxv) printf "%-40s %6.2f\n", k, maxv[k]
}' | sort -k2 -n
