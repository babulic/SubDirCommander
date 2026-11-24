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
    bounds = D64(str(work / "bounds9.d64"))
    for name, address in {
        b"B22FF": 0x22FF,
        b"B2300": 0x2300,
        b"B9FFF": 0x9FFF,
        b"BC000": 0xC000,
        b"BCFFF": 0xCFFF,
        b"BD000": 0xD000,
    }.items():
        image = bounds.read(name)
        assert image is not None and int.from_bytes(image[:2], "little") == address, (name, image)
    assert bounds.read(b"BAD:NAME") is not None
    print("PASS: deterministic VICE fixtures")


if __name__ == "__main__":
    main()
