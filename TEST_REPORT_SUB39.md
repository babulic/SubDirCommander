# SubDirCommander 3.9 — release test report

**Date:** 2026-11-24  
**Release commit:** `5414a54` (`main`)  
**Test backend:** VICE `x64sc`, 1541 true-drive D64 fixtures

## Result

**PASS — release build and the complete automated VICE suite passed.**

## Executed checks

| Command / suite | Result | What it verifies |
| --- | --- | --- |
| `sh tools/build.sh` | PASS | Rebuilds BASIC, ML, D64 and web release artifacts. |
| `python3 test/verify_artifacts.py` | PASS | BASIC/ML source-artifact agreement, helper payloads, D64 contents and BASIC-record limit (longest: line 5926, 193 bytes). |
| `python3 test/verify_fixtures.py /tmp/t` | PASS | Deterministic D64 fixtures, binary data and ML address-boundary PRGs. |
| `python3 test/verify_device_matrix.py` | PASS | README/web claims agree with the device capability matrix. |
| `test/runall.sh` | PASS, exit 0 | Entire BASIC and ML VICE scenario suite. |
| `test/run_device_matrix.sh sd2iec` | Expected SKIP, exit 77 | Missing SD2IEC firmware adapter is reported as SKIP, never PASS. |

## Asserted VICE coverage added for this release

- BASIC drive-list cursor/page/highlight state: `t5.py`.
- BASIC cross-drive PRG copy: byte-exact target content, one destination file,
  expected free-block delta and duplicate-file DOS status 63: `t6.py`.
- BASIC typed unsafe DOS name `bad:name` is rejected without changing the
  source file: `t15.py`.
- ML start-address boundaries `$22FF`, `$2300`, `$9FFF`, `$C000`, `$CFFF`,
  and raw listed unsafe name `BAD:NAME`: `m8.py`.

The full suite also exercises list/navigation, copy/move/delete/rename,
validate/format, Load/Run, disk-full handling and the ML frontend.

## Device coverage boundary

VICE true-drive D64 tests cover the 1541-compatible disk-image path used by
the Pi1541-D64 matrix target. SD2IEC, Pi1541 SD-card browser mode and Kung Fu
Flash need their own firmware/emulator adapters. Their runners are prepared in
`test/run_device_matrix.sh`, but without an adapter return explicit `SKIP`
(77); they are not firmware-level PASS results.

## Deliberate limitations

- The approved helper-trailer relocation to `$97F0-$9FFF` is not implemented
  in this release.
- Direct execution outside `$2300-$9FFF` and `$C000-$CFFF` is unsupported;
  in particular `$D000` is probed but not executed by the test suite.
- Remaining asserted-test gaps are listed in `CODE_REVIEW_CODEX_02.md`.
