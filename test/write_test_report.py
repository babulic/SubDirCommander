#!/usr/bin/env python3
"""Write human-readable current and category-scoped test reports."""

from __future__ import annotations

import argparse
import subprocess
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from test_catalog import DEVICE_TARGETS, FULL_SUITE, SCENARIOS


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "TEST_REPORT_SUB39.md"
HISTORY_DIR = ROOT / "test" / "reports"
SUITES = ("full-vice-regression", "vice-scenario", "device-matrix")
LEGACY_CATEGORIES = {
    "full-vice-regression": ("full-vice-regression", "runall"),
    "vice-scenario": ("vice-scenario", "scenario"),
    "device-matrix": ("device-matrix", "device"),
}
SUITE_INFO = {
    "full-vice-regression": (
        "Full BASIC + ML VICE regression suite",
        "Runs host artifact checks followed by every supported BASIC and ML VICE scenario on fresh fixtures.",
        "basic-and-ml",
    ),
    "vice-scenario": (
        "Single VICE scenario",
        "Runs one selected BASIC or ML scenario on fresh deterministic D64 fixtures.",
        "scenario",
    ),
    "device-matrix": (
        "Device capability matrix",
        "Runs one device-specific compatibility target or records its missing-adapter SKIP.",
        "device",
    ),
}


def git_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def outcome(status: int) -> str:
    if status == 0:
        return "PASS"
    if status == 77:
        return "SKIP"
    return "FAIL"


def target_info(suite: str, target: str | None) -> tuple[str, str, str, str]:
    if suite == "full-vice-regression":
        title, description, slug = SUITE_INFO[suite]
        return "all", title, description, slug
    items = SCENARIOS if suite == "vice-scenario" else DEVICE_TARGETS
    if target not in items:
        return target or "unknown", "Unknown test target", "Target is not in the official test catalog.", "unknown"
    title, description, slug = items[target]
    return target, title, description, slug


def clear_history(category: str) -> None:
    """Delete only this runner category's prior reports, preserving the other two."""
    HISTORY_DIR.mkdir(exist_ok=True)
    for report in HISTORY_DIR.glob("*.md"):
        if any(f"_{name}_" in report.name for name in LEGACY_CATEGORIES[category]):
            report.unlink()


def scenario_table() -> list[str]:
    lines = ["## Scenarios executed", "", "| ID | Test name | Purpose |", "| --- | --- | --- |"]
    for scenario in FULL_SUITE:
        title, description, _ = SCENARIOS[scenario]
        lines.append(f"| `{scenario}` | {title} | {description} |")
    return lines


def report_body(suite: str, target: str | None, status: int, moment: datetime) -> tuple[str, str, str]:
    target_id, test_name, description, slug = target_info(suite, target)
    runner_name, runner_description, _ = SUITE_INFO[suite]
    result = outcome(status)
    now = moment.strftime("%Y-%m-%d %H:%M:%S %Z")
    body = [
        "# SubDirCommander 3.9 — automated test report",
        "",
        "> Generated on runner exit. PASS, FAIL and missing-adapter SKIP results are all recorded.",
        "",
        "## Run identity",
        "",
        f"- **Generated:** {now}",
        f"- **Git HEAD when report was written:** `{git_commit()}`",
        f"- **Runner:** {runner_name}",
        f"- **Runner description:** {runner_description}",
        f"- **Test ID / target:** `{target_id}`",
        f"- **Test name:** {test_name}",
        f"- **Test description:** {description}",
        f"- **Exit status:** `{status}`",
        f"- **Result:** **{result}**",
        "",
        "## Execution",
        "",
    ]
    if suite == "full-vice-regression":
        body += [
            "The run executes `verify_artifacts.py`, `verify_device_matrix.py`, then every BASIC and ML VICE scenario below.",
            "Each scenario receives fresh D64 fixtures; one nonzero result stops the suite and records FAIL.",
            "",
        ]
        body.extend(scenario_table())
    elif suite == "vice-scenario":
        body += [
            "The runner creates fresh D64 fixtures with `mkdisks.sh`, validates them with `verify_fixtures.py`, then starts the selected scenario in VICE.",
        ]
    else:
        body += [
            "The runner invokes the selected device target. Without its required firmware/emulator adapter, exit 77 is recorded as SKIP rather than PASS.",
        ]
    body += [
        "",
        "## Report locations",
        "",
        "`TEST_REPORT_SUB39.md` is the latest result. `test/reports/` retains one current report per runner category: full suite, single scenario and device matrix.",
        "Starting a runner replaces only its own category's prior report.",
        "",
        "Open review items and architectural limits are in `CODE_REVIEW_CODEX_02.md`.",
    ]
    return "\n".join(body) + "\n", slug, result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clear-history", choices=SUITES)
    parser.add_argument("--suite", choices=SUITES)
    parser.add_argument("--status", type=int)
    parser.add_argument("--target")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--no-history", action="store_true")
    args = parser.parse_args()

    if args.clear_history:
        clear_history(args.clear_history)
        return
    if args.suite is None or args.status is None:
        parser.error("--suite and --status are required unless --clear-history is used")

    moment = datetime.now(ZoneInfo("Europe/Bratislava"))
    contents, slug, result = report_body(args.suite, args.target, args.status, moment)
    args.output.write_text(contents, encoding="utf-8")
    if args.no_history:
        return

    HISTORY_DIR.mkdir(exist_ok=True)
    stamp = moment.strftime("%Y-%m-%d_%H-%M-%S-%f")
    result_label = result if args.status == 0 else f"{result}-{args.status}"
    stem = f"{stamp}_{args.suite}_{slug}_{result_label}"
    attempt = 1
    while True:
        suffix = "" if attempt == 1 else f"_{attempt}"
        history = HISTORY_DIR / f"{stem}{suffix}.md"
        try:
            with history.open("x", encoding="utf-8") as report:
                report.write(contents)
            break
        except FileExistsError:
            attempt += 1


if __name__ == "__main__":
    main()
