"""Root-file rules on a non-CBM device root (VICE filesystem device 9).

A plain C64 file copies from the root into an opened D64, a disk image does
not, and a host file with a foreign extension (.crt) is never loaded.
"""

import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(os.environ["SDC40_WORK"])
sys.path.insert(0, str(ROOT / "test"))
from d64 import D64
from vice import DOWN, RET, UP, mlstart, pet, start

fsroot = WORK / "fsroot"
shutil.rmtree(fsroot, ignore_errors=True)
fsroot.mkdir()
(fsroot / "hello.prg").write_bytes(bytes([0x01, 0x08, 0x0B, 0x08, 0x0A, 0x00, 0x99, 0x22, 0x48, 0x49, 0x22, 0, 0, 0]))
(fsroot / "game.crt").write_bytes(b"C64 CARTRIDGE   " + bytes(48))
shutil.copy2(ROOT / "original" / "fb.d64", fsroot / "disk.d64")
FS9 = ["-drive9type", "0", "-busdevice9", "-fs9", str(fsroot)]


def selected(v, name, key):
    for move in [DOWN] * 6 + [UP] * 12:
        if name in v.screen()[v.highlighted_row()].lower():
            return
        key(move)
    raise AssertionError(f"not selected: {name}\n" + "\n".join(v.screen()))


# BASIC
target = WORK / "root-basic.d64"
shutil.copy2(ROOT / "dist" / "SubDirCommand.40.d64", target)
v = start(str(target), d9=None, drive=ord("9"), extra=FS9)
selected(v, "game.crt", v.key)
v.key(ord("7"), at=10)
assert v.wait_line(10, 60), f"CRT run did not return; BASIC line {v.line()}"
v.require_text("not a c64 program")
v.key(RET)
assert v.wait_line(10, 60)
selected(v, "hello.prg", v.key)
v.key(ord("4"), at=10)
assert v.wait_line(4340, 30)
v.keys([RET])
assert v.wait_line(6, 30)
v.keys(pet("8") + [RET])
assert v.wait_line(10, 120), f"plain copy did not return; BASIC line {v.line()}"
selected(v, "disk.d64", v.key)
v.key(ord("4"), at=10)
assert v.wait_line(4340, 30)
v.keys([RET])
assert v.wait_line(6, 30)
v.keys(pet("8") + [RET])
assert v.wait_line(10, 120)
v.require_text("target must be root")
v.quit()
image = D64(str(target))
assert image.read(b"HELLO.PRG") == (fsroot / "hello.prg").read_bytes(), "BASIC refused a plain root PRG"
assert image.read(b"DISK.D64") is None, "BASIC copied a disk image into an opened D64"

# ML
target = WORK / "root-ml.d64"
shutil.copy2(ROOT / "dist" / "SubDirCommand.40.d64", target)
v = mlstart(str(target), drive=ord("9"), extra=FS9)
selected(v, "game.crt", v.mkey)
v.mkey(ord("7"))
v.require_text("not a c64 program")
v.mkey(RET)
selected(v, "hello.prg", v.mkey)
v.mkey(ord("4"))
v.mkey(RET)
v.mtype(pet("8") + [RET])
v.require_text("hello.prg")
selected(v, "disk.d64", v.mkey)
v.mkey(ord("4"))
v.mkey(RET)
v.mtype(pet("8") + [RET])
v.require_text("target root only")
v.quit()
image = D64(str(target))
assert image.read(b"HELLO.PRG") == (fsroot / "hello.prg").read_bytes(), "ML refused a plain root PRG"
assert image.read(b"DISK.D64") is None, "ML copied a disk image into an opened D64"
print("PASS: 4.0 root files copy into a D64, images do not, and a CRT is never loaded")
