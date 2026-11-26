# SubDirCommander 4.0 — binary-trailer test report

> Generated when `test/run40.sh` exited. A nonzero result is recorded as FAIL.

## Run identity

- **Generated:** 2026-11-26 20:51:39 CET
- **Git HEAD when report was written:** `fad4b05`
- **Runner:** BASIC 4.0 binary-trailer regression
- **Purpose:** verifies the BASIC transport trailer, relocated resident helpers, cross-drive Copy, and direct Load/Run overwrite warnings.
- **Exit status:** `0`
- **Result:** **PASS**

## Execution

1. `tools/build40.py` builds `SubDirCommand.40.prg`, `%SubDirCommand.40.prg`, `SubDirCommand.40.d64`, and `fb.d64`.
2. `verify_artifacts40.py` checks the BASIC `$0000` terminator, literal bootstrap, exact trailer, three executable helper images plus the reserved directory-state range, and both disk images.
3. `v40_bootstrap.py` starts BASIC 4.0 in VICE, proves `$37/$38 = $97F0`, verifies valid directory text, the two-cell inverse title margin and the inverse space immediately after the disk ID, compares each relocated helper byte-for-byte, then corrupts the consumed transport and verifies ordinary `RUN`, fresh drive selection and relisting through the relocated-helper signature.
4. `v40_workflow.py` first attempts a Move to an already-present target, requires the replacement prompt, declines it and verifies title redraw plus both original files. It then accepts an overwrite for a byte-different target and checks the target bytes. It opens and declines a generic Delete-item dialog without a BASIC syntax error, copies across drives via `SYS $97F0`, directly loads a test PRG at `$C800`, then Load/Runs a BASIC PRG at `$0801` without a Commander warning. Finally it declines Load and Run of a nine-block PRG spanning `$97F0-$9FFF`, requiring the exact `Program will hit Commander's routines!` warning and unchanged helper memory.
5. `v40_overwrite_batch.py` creates four marked source files for each frontend, collides `!ULTRALOAD` at the target, requires the filename in the replacement prompt, accepts `Y`, and verifies byte-exact replacement plus all remaining batch files. This catches a target command channel left open after `S:`.
6. `v40_ml_smoke.py` starts the machine-language frontend from the release D64 and asserts that its live directory cursor moves down one entry. Structural checks also require normal command-channel opens (not the KFF-incompatible IEC probe), a post-MD/RD status read, the explicit KFF folder message, refresh of the cached DOS title on image entry/exit, and fixed 16-byte directory-name preservation.

## Report locations

`TEST_REPORT_SUB40.md` is the latest 4.0 result. `test/reports/` retains one timestamped binary-trailer report; a new `run40.sh` removes only the preceding report from this category. Its filename is `YYYY-MM-DD_HH-MM-SS-microseconds_basic40-binary-trailer_sub40-bootstrap-and-workflow_RESULT.md`.

The design and remaining accepted limits are documented in `CODE_REVIEW_CODEX_02.md`.
