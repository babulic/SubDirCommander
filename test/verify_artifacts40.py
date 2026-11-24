#!/usr/bin/env python3
"""Host-side structural checks for the SubDirCommander 4.0 BASIC release."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASIC_TEXT = ROOT / "basic" / "SubDirCommand.40.txt"
BASIC_PRG = ROOT / "dist" / "SubDirCommand.40.prg"
ML_PRG = ROOT / "dist" / "%SubDirCommand.40.prg"
TRAILER_PRG = ROOT / "build40" / "trailer40.prg"
HELPERS = (
    ("copyhelper", 0x97F0, 138),
    ("panel", 0x9930, 485),
    ("dirread", 0x9B20, 1104),
)


def basic_end(program: bytes) -> int:
    assert program[:2] == b"\x01\x08", "BASIC must load at $0801"
    offset = 2
    while True:
        next_line = int.from_bytes(program[offset : offset + 2], "little")
        if next_line == 0:
            return offset + 2
        end = program.index(0, offset + 4)
        assert 2 + next_line - 0x0801 == end + 1, "broken BASIC line link"
        offset = end + 1


def directory(path: Path) -> str:
    return subprocess.check_output(
        ["c1541", "-attach", str(path), "-dir"], text=True, stderr=subprocess.STDOUT
    )


source = BASIC_TEXT.read_text(encoding="latin-1")
match = re.search(
    r"^\s*1\s+on-sgn\(rl\)goto4489:poke55,240:poke56,151:clr:poke45,(\d+):poke46,(\d+):clr:sys(\d+)\s*$",
    source,
    re.IGNORECASE | re.MULTILINE,
)
assert match, "line 1 must contain the direct-load gate and numeric bootstrap"

program = BASIC_PRG.read_bytes()
end = basic_end(program)
trailer_address = 0x0801 + end - 2
vartab = int(match.group(1)) + 256 * int(match.group(2))
assert vartab == trailer_address
assert int(match.group(3)) == trailer_address
assert program[end:] == TRAILER_PRG.read_bytes()[2:], "raw trailer differs from assembler output"

for old_sys in (828, 49152, 50432, 50608, 51200):
    assert f"sys{old_sys}" not in source.lower(), f"old helper SYS {old_sys} remains"
for old_line in range(5925, 6125):
    assert not re.search(rf"^\s*{old_line}\s", source, re.MULTILINE), "old DATA helper transport remains"

payloads = []
for name, start, size in HELPERS:
    payload = (ROOT / "build40" / f"{name}.bin").read_bytes()
    assert len(payload) == size, name
    payloads.append(payload)
assert program[end:].endswith(b"".join(payloads)), "trailer helper payload order differs"

build = (ROOT / "tools" / "build40.py").read_text()
assert "HELPER_WORK=39072" in build
assert "HELPER_HEADER=39040" in build
assert "TITLE_MARGIN=1" in build
assert "HELPER_WORK = 0" in (ROOT / "basic" / "dirread.asm").read_text()
assert "peek(39040+i)" in source.lower()
assert "51200+i" not in source
assert '("hexpoke",' not in build
assert "HEX_DECODE" not in (ROOT / "basic" / "trailer40.asm").read_text()
assert "HEX DECODE" not in source
assert not (ROOT / "build40" / "hexpoke.bin").exists()
assert not (ROOT / "build40" / "dataskip.bin").exists()
assert "fori=1to31:readb,v:k%(b)=v:next" in source.lower()
assert "77,0,205,0" not in source

for image in (ROOT / "dist" / "SubDirCommand.40.d64", ROOT / "dist" / "fb.d64"):
    listing = directory(image)
    assert "SubDirCommand.40" in listing, image
    assert "%SubDirCommand40" in listing, image
assert ML_PRG.exists() and ML_PRG.stat().st_size > 2

print(f"PASS: 4.0 BASIC ends at ${trailer_address:04X}; binary trailer and media are exact")
