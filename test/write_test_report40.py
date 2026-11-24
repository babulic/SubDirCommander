#!/usr/bin/env python3
"""Write the latest and timestamped report for the SubDirCommander 4.0 run."""

from __future__ import annotations

import argparse
import subprocess
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[1]
LATEST = ROOT / "TEST_REPORT_SUB40.md"
HISTORY = ROOT / "test" / "reports"
CATEGORY = "basic40-binary-trailer"


def commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def result(status: int) -> str:
    return "PASS" if status == 0 else "FAIL"


def clear_history() -> None:
    HISTORY.mkdir(exist_ok=True)
    for report in HISTORY.glob(f"*_{CATEGORY}_*.md"):
        report.unlink()


def body(status: int, now: datetime) -> str:
    verdict = result(status)
    return f"""# SubDirCommander 4.0 — binary-trailer test report

> Generated when `test/run40.sh` exited. A nonzero result is recorded as FAIL.

## Run identity

- **Generated:** {now.strftime('%Y-%m-%d %H:%M:%S %Z')}
- **Git HEAD when report was written:** `{commit()}`
- **Runner:** BASIC 4.0 binary-trailer regression
- **Purpose:** verifies the BASIC transport trailer, relocated resident helpers, cross-drive Copy, and direct Load/Run overwrite warnings.
- **Exit status:** `{status}`
- **Result:** **{verdict}**

## Execution

1. `tools/build40.py` builds `SubDirCommand.40.prg`, `%SubDirCommand.40.prg`, `SubDirCommand.40.d64`, and `fb.d64`.
2. `verify_artifacts40.py` checks the BASIC `$0000` terminator, literal bootstrap, exact trailer, three executable helper images plus the reserved directory-state range, and both disk images.
3. `v40_bootstrap.py` starts BASIC 4.0 in VICE, proves `$37/$38 = $97F0`, verifies valid directory text, the two-cell inverse title margin and the inverse space immediately after the disk ID, compares each relocated helper byte-for-byte, then verifies clean Exit followed by ordinary `RUN`, fresh drive selection and relisting.
4. `v40_workflow.py` first attempts a Move to an already-present target, requires `FILE EXISTS`, verifies title redraw and both original files, then copies a file across drives via `SYS $97F0`. It directly loads a test PRG at `$C800`, proving that this address no longer contains Commander state. Finally it declines Load and Run of a nine-block PRG spanning `$97F0-$9FFF`, requiring all four exact service names in both warnings and unchanged helper memory.

## Report locations

`TEST_REPORT_SUB40.md` is the latest 4.0 result. `test/reports/` retains one timestamped binary-trailer report; a new `run40.sh` removes only the preceding report from this category. Its filename is `YYYY-MM-DD_HH-MM-SS-microseconds_basic40-binary-trailer_sub40-bootstrap-and-workflow_RESULT.md`.

The design and remaining accepted limits are documented in `CODE_REVIEW_CODEX_02.md`.
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clear-history", action="store_true")
    parser.add_argument("--status", type=int)
    args = parser.parse_args()
    if args.clear_history:
        clear_history()
        return
    if args.status is None:
        parser.error("--status is required unless --clear-history is used")

    now = datetime.now(ZoneInfo("Europe/Bratislava"))
    contents = body(args.status, now)
    LATEST.write_text(contents, encoding="utf-8")
    HISTORY.mkdir(exist_ok=True)
    stamp = now.strftime("%Y-%m-%d_%H-%M-%S-%f")
    path = HISTORY / f"{stamp}_{CATEGORY}_sub40-bootstrap-and-workflow_{result(args.status)}.md"
    with path.open("x", encoding="utf-8") as report:
        report.write(contents)


if __name__ == "__main__":
    main()
