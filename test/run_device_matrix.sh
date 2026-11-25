#!/usr/bin/env bash
# Run a SubDirCommander 4.0 device suite. Firmware runners come from the lab.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
device=${1:?"usage: test/run_device_matrix.sh DEVICE"}
python3 "$root/test/write_test_report40.py" --clear-history device-matrix

report() {
    local status=$?
    if [[ ${SDC_SUPPRESS_TEST_REPORT:-0} != 1 ]]; then
        python3 "$root/test/write_test_report40.py" --category device-matrix --target "$device" --status "$status" || true
    fi
    exit "$status"
}
trap report EXIT

run_pi1541_d64() {
    SDC_SUPPRESS_TEST_REPORT=1 bash "$root/test/run40.sh"
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
