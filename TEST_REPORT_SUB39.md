# SubDirCommander 3.9 — automated test report

> Generated on runner exit. PASS, FAIL and missing-adapter SKIP results are all recorded.

## Run identity

- **Generated:** 2026-11-24 16:55:58 CET
- **Git HEAD when report was written:** `0f84309`
- **Runner:** Single VICE scenario
- **Runner description:** Runs one selected BASIC or ML scenario on fresh deterministic D64 fixtures.
- **Test ID / target:** `t15`
- **Test name:** BASIC unsafe DOS-name rejection
- **Test description:** Proves typed `bad:name` is rejected without changing the source file.
- **Exit status:** `0`
- **Result:** **PASS**

## Execution

The runner creates fresh D64 fixtures with `mkdisks.sh`, validates them with `verify_fixtures.py`, then starts the selected scenario in VICE.

## Report locations

`TEST_REPORT_SUB39.md` is the latest result. `test/reports/` retains one current report per runner category: full suite, single scenario and device matrix.
Starting a runner replaces only its own category's prior report.

Open review items and architectural limits are in `CODE_REVIEW_CODEX_02.md`.
