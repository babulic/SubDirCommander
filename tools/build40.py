#!/usr/bin/env python3
"""Build SubDirCommander 4.0 with a BASIC binary helper trailer.

The BASIC listing ends normally at $0000.  Its first line lowers MEMSIZ,
performs CLR, then SYSes the following trailer.  The trailer is therefore a
transport format only: it relocates all helpers into $97F0-$9FFF before BASIC
allocates variables and arrays.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build40"
DIST = ROOT / "dist"
WEB_FILES = ROOT / "web" / "public" / "files"
BASIC_TEXT = ROOT / "basic" / "SubDirCommand.40.txt"
BASIC_PRG = DIST / "SubDirCommand.40.prg"
ML_PRG = DIST / "%SubDirCommand.40.prg"

HELPERS = (
    ("copyhelper", 0x97F0, 138),
    ("panel", 0x9930, 485),
    ("dirread", 0x9B20, 1104),
)


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def basic_end(program: bytes) -> int:
    """Return the file offset immediately following BASIC's $0000 terminator."""
    if program[:2] != b"\x01\x08":
        raise ValueError("BASIC PRG must load at $0801")
    offset = 2
    while True:
        if offset + 2 > len(program):
            raise ValueError("BASIC terminator missing")
        next_line = int.from_bytes(program[offset : offset + 2], "little")
        if next_line == 0:
            return offset + 2
        end = program.index(0, offset + 4)
        expected = 2 + next_line - 0x0801
        if expected != end + 1:
            raise ValueError(f"bad BASIC link at file offset {offset}")
        offset = expected


def bootstrap_literals(source: str) -> tuple[int, int, int]:
    match = re.search(
        r"^\s*1\s+on-sgn\(rl\)goto4489:poke55,240:poke56,151:clr:poke45,(\d+):poke46,(\d+):clr:sys(\d+)\s*$",
        source,
        re.IGNORECASE | re.MULTILINE,
    )
    if not match:
        raise ValueError("line 1 must be the literal MEMSIZ/VARTAB/CLR/SYS bootstrap")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def main() -> None:
    BUILD.mkdir(exist_ok=True)
    DIST.mkdir(exist_ok=True)
    WEB_FILES.mkdir(parents=True, exist_ok=True)
    # These helpers belong only to the 3.9 DATA-loader path.  Do not leave
    # stale 4.0-looking outputs behind after their removal from the trailer.
    for stale in ("dataskip.bin", "dataskip.prg", "hexpoke.bin", "hexpoke.prg"):
        (BUILD / stale).unlink(missing_ok=True)

    for name, address, expected_size in HELPERS:
        assembled = BUILD / f"{name}.prg"
        blob = BUILD / f"{name}.bin"
        run(
            "64tass", "-q", "-C", "--long-branch", "--cbm-prg",
            f"-DHELPER_ADDR={address}",
            *(
                ("-DHELPER_WORK=39072", "-DHELPER_HEADER=39040", "-DTITLE_MARGIN=1")
                if name == "dirread" else ()
            ),
            "-o", str(assembled),
            str(ROOT / "basic" / f"{name}.asm"),
        )
        helper = assembled.read_bytes()
        if int.from_bytes(helper[:2], "little") != address:
            raise ValueError(f"{name} load address differs from ${address:04X}")
        if len(helper) - 2 > expected_size:
            raise ValueError(f"{name} exceeds planned {expected_size} bytes")
        # Keep every planned range fixed-size even when a helper's BSS lives
        # outside its code block.  The zero tail belongs to its reservation.
        blob.write_bytes(helper[2:] + bytes(expected_size - (len(helper) - 2)))

    basic_transport = BUILD / "basic40-transport.prg"
    run("petcat", "-w2", "-o", str(basic_transport), "--", str(BASIC_TEXT))
    basic = basic_transport.read_bytes()
    trailer_offset = basic_end(basic)
    trailer_address = 0x0801 + trailer_offset - 2
    vartab_low, vartab_high, configured_address = bootstrap_literals(
        BASIC_TEXT.read_text(encoding="latin-1")
    )
    if configured_address != trailer_address:
        raise ValueError(
            f"line 1 SYS {configured_address} does not match trailer ${trailer_address:04X}; "
            "update the literal after changing the BASIC listing"
        )
    if vartab_low + 256 * vartab_high != trailer_address:
        raise ValueError("line 1 VARTAB POKEs do not point at the trailer start")

    trailer_prg = BUILD / "trailer40.prg"
    run(
        "64tass", "-q", "-C", "--long-branch", "--cbm-prg",
        f"-DTRAILER_ADDR={trailer_address}", "-o", str(trailer_prg),
        str(ROOT / "basic" / "trailer40.asm"),
    )
    trailer = trailer_prg.read_bytes()
    if int.from_bytes(trailer[:2], "little") != trailer_address:
        raise ValueError("trailer was assembled at the wrong address")
    BASIC_PRG.write_bytes(basic + trailer[2:])

    run(
        "64tass", "-q", "-C", "--long-branch", "--cbm-prg",
        "-o", str(ML_PRG), str(ROOT / "ml" / "sdc40.asm"),
    )

    fb = DIST / "fb.d64"
    shutil.copyfile(ROOT / "original" / "fb.d64", fb)
    run(
        "c1541", "-attach", str(fb),
        "-delete", "SubDirCommand.37",
        "-delete", "SubDirCommand.38",
        "-delete", "SubDirCommand.39",
        "-delete", "SubDirCommand.40",
        "-delete", "dc64",
        "-delete", "unformat.dsk.ib3",
        "-write", str(BASIC_PRG), "SubDirCommand.40",
        "-delete", "%SubDirCommand38",
        "-delete", "%SubDirCommand39",
        "-delete", "%SubDirCommand40",
        "-write", str(ML_PRG), "%SubDirCommand40",
    )

    slim = DIST / "SubDirCommand.40.d64"
    run(
        "c1541", "-format", "subdir commander,40", "d64", str(slim),
        "-write", str(BASIC_PRG), "SubDirCommand.40",
        "-write", str(ML_PRG), "%SubDirCommand40",
    )

    shutil.copyfile(BASIC_PRG, WEB_FILES / BASIC_PRG.name)
    shutil.copyfile(ML_PRG, WEB_FILES / ML_PRG.name)
    shutil.copyfile(slim, WEB_FILES / slim.name)

    blocks = (len(BASIC_PRG.read_bytes()) + 253) // 254
    print(
        f"PASS: SubDirCommander 4.0 built; trailer at ${trailer_address:04X}, "
        f"BASIC {blocks} blocks, helpers at $97F0-$9FFF"
    )


if __name__ == "__main__":
    main()
