#!/usr/bin/env python3
"""Apply fixture mutations that c1541's filename parser cannot express."""

from __future__ import annotations

import sys
from pathlib import Path

from d64 import D64, off


def rename_raw(path: Path, old: bytes, new: bytes) -> None:
    disk = D64(str(path))
    location, _ = disk.find(old)
    if location is None:
        raise AssertionError(f"missing {old!r} in {path}")
    track, sector, index = location
    start = off(track, sector) + index * 32 + 5
    disk.d[start : start + 16] = new.ljust(16, b"\xa0")
    disk.save()


def main() -> None:
    work = Path(sys.argv[1] if len(sys.argv) == 2 else "/tmp/t")
    # A colon in a real directory entry is intentionally not sent through
    # c1541's DOS-command parser. Both frontends must refuse destructive
    # actions for this selected entry.
    rename_raw(work / "bounds9.d64", b"UNSAFE", b"BAD:NAME")


if __name__ == "__main__":
    main()
