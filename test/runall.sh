#!/usr/bin/env bash
# Run every BASIC and machine-language VICE scenario.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=/tmp/t
limit=${SDC_TEST_TIMEOUT:-1200}

run() {
    local scenario=$1
    echo "### $scenario"
    bash "$root/test/mkdisks.sh" "$root" "$work"
    python3 "$root/test/verify_fixtures.py" "$work"
    timeout "$limit" python3 "$root/test/$scenario.py"
}

python3 "$root/test/verify_artifacts.py"
python3 "$root/test/verify_device_matrix.py"

# BASIC V2 release: navigation, copy/error cleanup, load/run, file commands
# and start-address handling.
for scenario in t4 t5 t6 t7 t8 t9 t10 t11 t12 t13 t14 t15; do
    run "$scenario"
done

# 6502 release: its own screen navigation and every command family.
for scenario in m1 m2 m4 m5 m6 m7 m8; do
    run "$scenario"
done
