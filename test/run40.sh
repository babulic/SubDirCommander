#!/usr/bin/env bash
# Build and test the BASIC 4.0 binary-trailer bootstrap on a fresh VICE C64.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d /private/tmp/sdc40-test.XXXXXX)

if [[ ${SDC_SUPPRESS_TEST_REPORT:-0} != 1 ]]; then
    python3 "$root/test/write_test_report40.py" --clear-history basic40-binary-trailer
fi

report() {
    local status=$?
    rm -rf "$work"
    if [[ ${SDC_SUPPRESS_TEST_REPORT:-0} != 1 ]]; then
        python3 "$root/test/write_test_report40.py" --status "$status" || true
    fi
    exit "$status"
}
trap report EXIT

python3 "$root/tools/build40.py"
python3 "$root/test/verify_artifacts40.py"
cp "$root/dist/fb.d64" "$work/target.d64"
cp "$root/original/fb.d64" "$work/source.d64"
64tass -q --cbm-prg -DADDR=38896 -o "$work/overlap.prg" "$root/test/resident_overlap.asm"
64tass -q --cbm-prg -DADDR=38897 -o "$work/overlap-target.prg" "$root/test/resident_overlap.asm"
64tass -q --cbm-prg -DADDR=51200 -o "$work/c800.prg" "$root/test/boundary.asm"
petcat -w2 -o "$work/basic0801.prg" -- "$root/test/basic_handoff.txt"
c1541 -attach "$work/source.d64" -write "$work/c800.prg" c800 >/dev/null
c1541 -attach "$work/source.d64" -write "$work/basic0801.prg" basic0801 >/dev/null
c1541 -attach "$work/target.d64" -write "$work/overlap.prg" overlap >/dev/null
c1541 -attach "$work/source.d64" -write "$work/overlap-target.prg" overlap >/dev/null

export SDC40_WORK="$work"
timeout "${SDC_TEST_TIMEOUT:-300}" python3 "$root/test/v40_bootstrap.py"
timeout "${SDC_TEST_TIMEOUT:-600}" python3 "$root/test/v40_workflow.py"
timeout "${SDC_TEST_TIMEOUT:-600}" python3 "$root/test/v40_overwrite_batch.py"
timeout "${SDC_TEST_TIMEOUT:-300}" python3 "$root/test/v40_ml_smoke.py"
timeout "${SDC_TEST_TIMEOUT:-600}" python3 "$root/test/v40_root_files.py"
