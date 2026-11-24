# SubDirCommander 3.9 — automated test report

> Generated on runner exit. PASS, FAIL and missing-adapter SKIP results are all recorded.

## Run identity

- **Generated:** 2026-11-24 17:48:47 CET
- **Git HEAD when report was written:** `c23f98c`
- **Runner:** Full BASIC + ML VICE regression suite
- **Runner description:** Runs host artifact checks followed by every supported BASIC and ML VICE scenario on fresh fixtures.
- **Test ID / target:** `all`
- **Test name:** Full BASIC + ML VICE regression suite
- **Test description:** Runs host artifact checks followed by every supported BASIC and ML VICE scenario on fresh fixtures.
- **Exit status:** `0`
- **Result:** **PASS**

## Execution

The run executes `verify_artifacts.py`, `verify_device_matrix.py`, then every BASIC and ML VICE scenario below.
Each scenario receives fresh D64 fixtures; one nonzero result stops the suite and records FAIL.

## Scenarios executed

| ID | Test name | Purpose |
| --- | --- | --- |
| `t4` | BASIC navigation smoke test | Shows the initial directory and exercises page and cursor movement. |
| `t5` | BASIC cursor and page assertions | Asserts the highlighted row and selected entry across page changes and wraps. |
| `t6` | BASIC cross-drive copy integrity | Checks byte-exact PRG copy, free-block delta and duplicate-file status 63. |
| `t7` | BASIC large copy and disk-full handling | Copies Oxford Pascal, then exercises SEQ copy into a full target disk. |
| `t8` | BASIC Load and subsequent SAVE | Loads a BASIC program, inspects BASIC pointers, then saves and lists it. |
| `t9` | BASIC Run/Load machine-code paths | Runs $C000 ML, copies a SEQ file and hands $1000 ML back to BASIC. |
| `t10` | BASIC ML handoff memory state | Runs overlapping $1000 ML and observes BASIC pointers and key-repeat state. |
| `t11` | BASIC command workflow | Exercises validate, rename, start-address display, delete and exit. |
| `t12` | BASIC disk-full copy result | Copies a selected file to the full target and observes DOS disk-full status. |
| `t13` | BASIC direct Load at $C000 | Loads a $C000 program without running it and observes the selected entry. |
| `t14` | BASIC and ML start-address display | Checks start-address display and cross-drive SEQ copy in both frontends. |
| `t15` | BASIC INPUT unsafe DOS-name rejection | Proves quoted `bad:name` is rejected without changing the source file. |
| `t16` | BASIC marked-file cross-drive copy | Marks FILE05 with Space and verifies that Copy transfers that marked file byte-exactly. |
| `m1` | ML navigation smoke test | Shows the ML frontend and exercises basic cursor and page movement. |
| `m2` | ML navigation and command workflow | Exercises page/wrap navigation, start address, rename, delete and validate. |
| `m4` | ML disk-full and duplicate copy handling | Exercises cross-drive copy failures on a full target and duplicate outcomes. |
| `m5` | ML cross-drive copy, Run and Load | Copies Oxford Pascal, runs $C000 ML and performs Load-only behavior. |
| `m6` | ML BASIC/ML handoff and exit | Covers BASIC Load/Run, overlapping ML handoff, exit and rerun behavior. |
| `m7` | External commander launch | Launches the dc64 program from both ML and BASIC frontends. |
| `m8` | ML memory boundaries and unsafe listed names | Checks supported ML boundaries, probes $D000 and rejects raw BAD:NAME deletion. |

## Report locations

`TEST_REPORT_SUB39.md` is the latest result. `test/reports/` retains one current report per runner category: full suite, single scenario and device matrix.
Starting a runner replaces only its own category's prior report.

Open review items and architectural limits are in `CODE_REVIEW_CODEX_02.md`.
