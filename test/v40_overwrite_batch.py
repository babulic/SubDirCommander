"""Regression for accepted FILE EXISTS replacement in BASIC and ML batches."""

import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORK = Path(os.environ["SDC40_WORK"])
sys.path.insert(0, str(ROOT / "test"))
from d64 import D64
from vice import DOWN, RET, mlstart, pet, start


NAME_TEXTS = ("!ULTRALOAD", "BATCHONE", "BATCHTWO", "BATCHTHREE")
# c1541 converts the alphabetic part of a directory name to high-bit PETSCII.
# Compare the same bytes that Commander receives from the IEC directory.
NAMES = tuple(bytes(pet(name)) for name in NAME_TEXTS)
DISPLAY_NAMES = tuple(name.lower() for name in NAME_TEXTS)
SOURCE_PAYLOAD = WORK / "c800.prg"
OLD_TARGET_PAYLOAD = WORK / "overlap-target.prg"


def add(image: Path, payload: Path, name: str) -> None:
    subprocess.run(
        ["c1541", "-attach", str(image), "-write", str(payload), name],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def fixtures(frontend: str) -> tuple[Path, Path, dict[bytes, bytes]]:
    source = WORK / f"{frontend}-batch-source.d64"
    target = WORK / f"{frontend}-batch-target.d64"
    release = ROOT / "dist" / "SubDirCommand.40.d64"
    shutil.copy2(release, source)
    shutil.copy2(release, target)
    for name in NAME_TEXTS:
        add(source, SOURCE_PAYLOAD, name)
    add(target, OLD_TARGET_PAYLOAD, NAME_TEXTS[0])
    expected = {name: D64(str(source)).read(name) for name in NAMES}
    assert all(expected.values())
    assert D64(str(target)).read(NAMES[0]) != expected[NAMES[0]]
    return source, target, expected


def selected(v, name: str, ml: bool) -> None:
    for _ in range(24):
        if name in v.screen()[v.highlighted_row()].lower():
            return
        if ml:
            v.mkey(DOWN)
        else:
            v.key(DOWN)
    raise AssertionError(f"not selected: {name}")


def mark_all(v, ml: bool) -> None:
    for name in DISPLAY_NAMES:
        selected(v, name, ml)
        if ml:
            v.mkey(ord(" "))
        else:
            v.key(ord(" "))


def assert_target(target: Path, expected: dict[bytes, bytes]) -> None:
    image = D64(str(target))
    for name, data in expected.items():
        assert image.read(name) == data, f"target was not replaced/copied: {name!r}"


# BASIC: the prompt must include the colliding marked filename and Y must
# replace it, then continue to all remaining marked files.
basic_source, basic_target, basic_expected = fixtures("basic")
v = start(str(basic_source), d9=str(basic_target))
mark_all(v, ml=False)
v.key(ord("4"), at=10)
assert v.wait_line(6, 30)
v.keys(pet("9") + [RET])
assert v.wait_line(4, 120)
v.require_text("rewrite target")
v.require_text("ultraload")
v.keys(pet("y"))
assert v.wait_line(10, 240)
v.quit()
assert_target(basic_target, basic_expected)


# ML uses the same 4-file batch.  Its prompt is full width so a 16-character
# target remains visible; in particular it must contain !ULTRALOAD here.
ml_source, ml_target, ml_expected = fixtures("ml")
v = mlstart(str(ml_source), d9=str(ml_target))
mark_all(v, ml=True)
v.mkey(ord("4"))
v.mtype(pet("9") + [RET])
assert v.wait_text("Rewrite target", 120)
v.require_text("ultraload")
# ML GETIN receives PETSCII; ASCII 0x79 is not the C64's lowercase-mode Y.
v.mkey(pet("y")[0])
assert v.idle(240)
v.quit()
assert_target(ml_target, ml_expected)

print("PASS: BASIC and ML batch overwrite retain target name and replace all files")
