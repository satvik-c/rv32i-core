#!/usr/bin/env bash
# Usage: regression_summary.sh <log_dir> <reports_dir>
# Aggregates per-test dsim logs and dcreport output into one PASS/FAIL table.
# Exit code is 0 iff every test passed with no SVA failures.
set -euo pipefail

LOG_DIR="$1"
REPORTS_DIR="$2"
overall_fail=0
tot_assertions=0
tot_evaluations=0
tot_passes=0
tot_disables=0
tot_failures=0
tot_retirements=0
tot_scb_errors=0

printf "%-32s %-8s %-10s %-10s %s\n" "TEST" "SCB" "SVA_FAIL" "FUNC_COV" "DETAIL"
printf -- '--------------------------------------------------------------------------------\n'

shopt -s nullglob
for log in "$LOG_DIR"/*.log; do
    name=$(basename "$log" .log)

    scb_line=$(grep -E "^SCOREBOARD: (PASS|FAIL)" "$log" || true)
    sva_line=$(grep -E "^SVA Summary:" "$log" || true)

    if echo "$scb_line" | grep -q PASS; then
        scb_status="PASS"
        n=$(echo "$scb_line" | grep -oE '[0-9]+' | head -1)
        tot_retirements=$((tot_retirements + n))
        scb_detail="${n} retired"
    elif echo "$scb_line" | grep -q FAIL; then
        scb_status="FAIL"
        overall_fail=1
        n=$(echo "$scb_line" | grep -oE '[0-9]+' | head -1)
        tot_scb_errors=$((tot_scb_errors + n))
        scb_detail="${n} errors"
    else
        scb_status="NORUN"
        overall_fail=1
        scb_detail="no scoreboard result"
    fi

    a=$(echo "$sva_line" | grep -oE '[0-9]+ assertions' | grep -oE '[0-9]+' || echo 0)
    e=$(echo "$sva_line" | grep -oE '[0-9]+ evaluations' | grep -oE '[0-9]+' || echo 0)
    p=$(echo "$sva_line" | grep -oE '[0-9]+ nonvacuous passes' | grep -oE '[0-9]+' || echo 0)
    d=$(echo "$sva_line" | grep -oE '[0-9]+ disables' | grep -oE '[0-9]+' || echo 0)
    f=$(echo "$sva_line" | grep -oE '[0-9]+ failures' | grep -oE '[0-9]+' || echo 0)

    tot_assertions=$((tot_assertions + a))
    tot_evaluations=$((tot_evaluations + e))
    tot_passes=$((tot_passes + p))
    tot_disables=$((tot_disables + d))
    tot_failures=$((tot_failures + f))
    if [ "$f" -gt 0 ]; then overall_fail=1; fi

    idx="$REPORTS_DIR/$name/index.html"
    func_cov="N/A"
    if [ -f "$idx" ]; then
        func_cov=$(grep -oE 'tb_top\.rvfi_cov_u.{0,100}' "$idx" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+%' | head -1 || true)
        [ -z "$func_cov" ] && func_cov="N/A"
    fi

    printf "%-32s %-8s %-10s %-10s %s\n" "$name" "$scb_status" "$f" "$func_cov" "$scb_detail"
done

printf -- '--------------------------------------------------------------------------------\n'
printf "TOTAL: %d retirements checked, %d scoreboard errors, %d SVA evaluations (%d nonvacuous passes, %d disabled, %d FAILED)\n" \
    "$tot_retirements" "$tot_scb_errors" "$tot_evaluations" "$tot_passes" "$tot_disables" "$tot_failures"
echo "FUNC_COV is each test's own rvfi_cov_u functional coverage, not the regression-wide union."

if [ "$overall_fail" -eq 0 ]; then
    echo "REGRESSION: PASS"
else
    echo "REGRESSION: FAIL"
fi

exit $overall_fail
