#!/usr/bin/env bash
# Run one VICE scenario with fresh fixtures and regenerate the latest report.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=/tmp/t
scenario=${1:?"usage: test/run_scenario.sh t5|...|m8"}
limit=${SDC_TEST_TIMEOUT:-1200}

python3 "$root/test/write_test_report.py" --clear-history vice-scenario

report() {
    local status=$?
    python3 "$root/test/write_test_report.py" --suite vice-scenario --target "$scenario" --status "$status" || true
    exit "$status"
}
trap report EXIT

case "$scenario" in
    t4|t5|t6|t7|t8|t9|t10|t11|t12|t13|t14|t15|t16|m1|m2|m4|m5|m6|m7|m8) ;;
    *) echo "unknown scenario: $scenario" >&2; exit 64 ;;
esac

bash "$root/test/mkdisks.sh" "$root" "$work"
python3 "$root/test/verify_fixtures.py" "$work"
timeout "$limit" python3 "$root/test/$scenario.py"
