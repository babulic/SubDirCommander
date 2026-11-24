#!/usr/bin/env python3
"""Assert the directory order and binary contents required by VICE scenarios."""

from __future__ import annotations

import sys
from pathlib import Path

from d64 import D64, name_str


def files(path: Path) -> list[str]:
    disk = D64(str(path))
    return [
        name_str(bytes(entry[5:21]))
        for _, entry in disk.entries()
        if (entry[2] & 7) and (entry[2] & 0x80)
    ]


def main() -> None:
    work = Path(sys.argv[1] if len(sys.argv) == 2 else "/tmp/t")
    big = files(work / "big2.d64")
    assert len(big) == 60, len(big)
    assert [big[index] for index in (50, 51, 52, 58, 59)] == [
        "mlc000",
        "ml1000",
        "smallseq",
        "seqfile",
        "oxford pascal",
    ]
    assert D64(str(work / "big2.d64")).read(b"SMALLSEQ") == (work / "smallseq.bin").read_bytes()
    assert "smallseq" in files(work / "full9.d64")
    print("PASS: deterministic VICE fixtures")


if __name__ == "__main__":
    main()
