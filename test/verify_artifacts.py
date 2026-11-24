#!/usr/bin/env python3
"""Host-side regression checks for the two SubDirCommander 3.9 releases.

The emulator suite tests interaction.  This check covers the release chain
that VICE cannot see: tokenisation, assembly, the BASIC helper payloads and
the two distributable D64 images.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from d64 import D64


ROOT = Path(__file__).resolve().parents[1]
BASIC_TEXT = ROOT / "basic" / "SubDirCommand.39.txt"
BASIC_PRG = ROOT / "dist" / "SubDirCommand.39.prg"
ML_SOURCE = ROOT / "ml" / "sdc39.asm"
ML_PRG = ROOT / "dist" / "%SubDirCommand39.prg"
BASIC_NAME = b"\xd3UB\xc4IR\xc3OMMAND.39"
ML_NAME = b"%\xd3UB\xc4IR\xc3OMMAND39"
HELPERS = (
    "hexpoke.asm",
    "copyhelper.asm",
    "dirread.asm",
    "panel.asm",
)


def executable(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise AssertionError(f"missing required executable: {name}")
    return path


def command(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def listing(path: Path) -> list[tuple[int, str]]:
    """Normalise petcat's display padding but retain every BASIC token."""
    result: list[tuple[int, str]] = []
    for raw in path.read_text(encoding="latin-1").splitlines():
        matched = re.fullmatch(r"\s*(\d+)\s(.*)", raw)
        if not matched:
            raise AssertionError(f"invalid BASIC listing line: {raw!r}")
        result.append((int(matched.group(1)), matched.group(2)))
    return result


def data_blob(source: str) -> bytes:
    blob = bytearray()
    for raw in source.splitlines():
        matched = re.fullmatch(r"\s*\d+\s+data(.*)", raw, re.IGNORECASE)
        if not matched:
            continue
        value = matched.group(1).strip()
        if value.startswith('"') and value.endswith('"'):
            blob.extend(bytes.fromhex(value[1:-1]))
        else:
            blob.extend(int(item) for item in value.split(","))
    return bytes(blob)


def dataskip_payload(source: str) -> bytes:
    pieces: list[str] = []
    for line_number in (5925, 5926):
        matched = re.search(
            rf"^\s*{line_number}\s+h\$=\"([0-9a-f]+)\"",
            source,
            re.IGNORECASE | re.MULTILINE,
        )
        if not matched:
            raise AssertionError(f"missing H$ payload at BASIC line {line_number}")
        pieces.append(matched.group(1))
    return bytes.fromhex("".join(pieces))


def basic_record_sizes(path: Path) -> list[tuple[int, int]]:
    """Return (line number, encoded record size) for a BASIC V2 PRG."""
    data = path.read_bytes()
    assert data[:2] == b"\x01\x08", f"unexpected BASIC load address: {path}"
    sizes: list[tuple[int, int]] = []
    offset = 2
    while True:
        next_address = int.from_bytes(data[offset : offset + 2], "little")
        if next_address == 0:
            break
        line_number = int.from_bytes(data[offset + 2 : offset + 4], "little")
        end = data.index(0, offset + 4)
        sizes.append((line_number, end - offset + 1))
        expected_offset = 2 + next_address - 0x0801
        assert expected_offset == end + 1, (line_number, next_address, end)
        offset = expected_offset
    return sizes


def labels(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    for raw in path.read_text(encoding="latin-1").splitlines():
        matched = re.match(r"(\w+)\s*=\s*\$([0-9a-f]+)", raw, re.IGNORECASE)
        if matched:
            values[matched.group(1)] = int(matched.group(2), 16)
    return values


def assert_disk(path: Path) -> None:
    disk = D64(str(path))
    assert disk.read(BASIC_NAME) == BASIC_PRG.read_bytes(), path
    assert disk.read(ML_NAME) == ML_PRG.read_bytes(), path
    for old_name in (
        b"\xd3UB\xc4IR\xc3OMMAND.37",
        b"\xd3UB\xc4IR\xc3OMMAND.38",
        b"%\xd3UB\xc4IR\xc3OMMAND38",
    ):
        assert disk.read(old_name) is None, (path, old_name)


def main() -> None:
    petcat = executable("petcat")
    tass = executable("64tass")
    source = BASIC_TEXT.read_text(encoding="latin-1")
    with tempfile.TemporaryDirectory(prefix="sdc39-artifacts-") as directory:
        temporary = Path(directory)
        decoded = temporary / "decoded.bas"
        rebuilt_ml = temporary / "sdc39ml.prg"
        rebuilt_labels = temporary / "sdc39ml.lbl"
        command(petcat, "-2", "-o", str(decoded), "--", str(BASIC_PRG))
        assert listing(decoded) == listing(BASIC_TEXT), "BASIC source and PRG differ"
        longest_line, longest_size = max(basic_record_sizes(BASIC_PRG), key=lambda item: item[1])
        assert longest_size <= 200, ("BASIC line too long", longest_line, longest_size)
        command(tass, "-q", "-C", "--long-branch", "--cbm-prg", "-l", str(rebuilt_labels), "-o", str(rebuilt_ml), str(ML_SOURCE))
        assert rebuilt_ml.read_bytes() == ML_PRG.read_bytes(), "ML source and PRG differ"
        assert labels(rebuilt_labels)["bufstart"] == 0x2300, "ML buffer start changed"
        assert "gosub4478" in source and "fori=1tolen(n$)" in source, "BASIC DOS-name guard missing"
        assert "safeold" in ML_SOURCE.read_text(encoding="latin-1"), "ML DOS-name guard missing"

        helpers: list[bytes] = []
        for helper in HELPERS:
            assembled = temporary / f"{helper}.prg"
            command(tass, "-q", "-C", "--long-branch", "--cbm-prg", "-o", str(assembled), str(ROOT / "basic" / helper))
            helpers.append(assembled.read_bytes()[2:])
        # The four helpers are read in this exact order from BASIC DATA.
        assert data_blob(source).startswith(b"".join(helpers)), "BASIC DATA helper payload differs from assembly source"

        dataskip = temporary / "dataskip.prg"
        command(tass, "-q", "-C", "--long-branch", "--cbm-prg", "-o", str(dataskip), str(ROOT / "basic" / "dataskip.asm"))
        assert dataskip_payload(source) == dataskip.read_bytes()[2:], "BASIC H$ data-skip payload differs from assembly source"

    assert_disk(ROOT / "dist" / "SubDirCommand.39.d64")
    assert_disk(ROOT / "dist" / "fb.d64")
    print(
        "PASS: BASIC, ML, helper payloads and release D64 images agree "
        f"(longest BASIC line {longest_line}: {longest_size} bytes)"
    )


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
