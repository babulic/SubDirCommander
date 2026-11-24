#!/usr/bin/env bash
# Run a sub39 device suite. Firmware runners are supplied by the test lab.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
device=${1:?"usage: test/run_device_matrix.sh DEVICE"}
work=/tmp/t

run_pi1541_d64() {
    bash "$root/test/mkdisks.sh" "$root" "$work"
    python3 "$root/test/verify_fixtures.py" "$work"
    for scenario in t5 t6 t7 t8 t11 t15 m2 m4 m5 m6 m8; do
        echo "### pi1541-d64 / $scenario"
        timeout "${SDC_TEST_TIMEOUT:-1200}" python3 "$root/test/$scenario.py"
    done
}

run_adapter() {
    local variable=$1
    local runner=${!variable:-}
    if [[ -z "$runner" ]]; then
        echo "SKIP: $device requires $variable" >&2
        exit 77
    fi
    "$runner" "$device" "$root/test/DEVICE_MATRIX.md"
}

case "$device" in
    pi1541-d64) run_pi1541_d64 ;;
    sd2iec) run_adapter SDC_SD2IEC_RUNNER ;;
    pi1541-sd) run_adapter SDC_PI1541_SD_RUNNER ;;
    kungfuflash) run_adapter SDC_KFF_RUNNER ;;
    *) echo "unknown device: $device" >&2; exit 64 ;;
esac
