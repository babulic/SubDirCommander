"""Exercise relocated 4.0 copy code and both overlap-warning prompts."""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(os.environ["SDC40_WORK"])
sys.path.insert(0, str(ROOT / "test"))
from d64 import D64
from vice import DOWN, RET, pet, start


NAME40 = [0xD3] + pet("ub") + [0xC4] + pet("ir") + [0xC3] + pet("ommand.40")
target_path = WORK / "target.d64"
source_path = WORK / "source.d64"


def selected(v, name: str) -> None:
    for _ in range(40):
        if name in v.screen()[v.highlighted_row()].lower():
            return
        v.key(DOWN)
    raise AssertionError(f"not selected: {name}")


# A failed cross-drive Move must preserve both files and redraw the source
# title correctly after the FILE EXISTS status is dismissed.
v = start(str(target_path), name=NAME40, d9=str(source_path))
selected(v, "overlap")
title_tail = v.mem(0x0442, 0x0442)
before_source = D64(str(target_path)).read(b"OVERLAP")
before_target = D64(str(source_path)).read(b"OVERLAP")
assert before_source is not None and before_target is not None
v.key(ord("9"), at=10)
assert v.wait_line(4603, 30)
v.keys([RET])
assert v.wait_line(6, 30)
v.keys(pet("9") + [RET])
assert v.wait_line(4, 120)
v.require_text("file exists")
v.keys(pet("x"))
assert v.wait_line(10, 120)
v.require_text("frequently used")
assert v.mem(0x0442, 0x0442) == title_tail
assert D64(str(target_path)).read(b"OVERLAP") == before_source
assert D64(str(source_path)).read(b"OVERLAP") == before_target
v.quit()

v = start(str(target_path), name=NAME40, d9=str(source_path), drive=ord("9"))
selected(v, "unformat")

# This reaches SYS $97F0, not the old cassette-buffer SYS $033C.
v.key(ord("4"), at=10)
assert v.wait_line(4340, 30)
v.keys([RET])
assert v.wait_line(6, 30)
v.keys(pet("8") + [RET])
assert v.wait_line(10, 600)

# $C800 belongs to the loaded program, not to 4.0 Commander state.  Load an
# RTS PRG there and prove that the resident copy helper and disk header remain.
selected(v, "c800")
copy_before = v.mem(0x97F0, 0x97F1)
v.key(ord("8"), at=10)
if not v.wait_line(10, 120):
    v.show("$C800 direct Load did not return")
    raise AssertionError(f"$C800 direct Load stopped at BASIC line {v.line()}")
assert v.mem(0xC800, 0xC800) == b"\x60"
assert v.mem(0x97F0, 0x97F1) == copy_before
v.require_text("frequently used")
v.quit()

source = D64(str(source_path)).read(b"UNFORMAT.DSK.IB3")
target = D64(str(target_path)).read(b"UNFORMAT.DSK.IB3")
assert source is not None and target == source

# A real BASIC PRG at $0801 replaces the Commander. Both commands must hand
# it to BASIC directly; neither may stop at the resident-range confirmation.
for key, expected in ((ord("7"), "basic handoff"), (ord("8"), "ready.")):
    v = start(str(target_path), name=NAME40, d9=str(source_path), drive=ord("9"))
    selected(v, "basic0801")
    v.key(key, at=10)
    assert v.wait_text(expected, 60), f"BASIC handoff did not finish after key {chr(key)}"
    assert not any("program will hit commander's routines!" in row.lower() for row in v.screen())
    v.quit()

# Restart to test the one-range direct-LOAD/RUN warning. Declining must leave
# the helper byte intact and return to the list for both commands.
v = start(str(target_path), name=NAME40, d9=str(source_path), drive=ord("9"))
selected(v, "overlap")
for key, action in ((ord("8"), "load"), (ord("7"), "run")):
    before = v.mem(0x97F0, 0x97F1)
    v.key(key, at=10)
    # The prompt first executes GOSUB 4, whose WAIT keeps BASIC on line 4
    # until we supply y/n.  Sampling only transient line 4545 would make a
    # real dialog look like a failed test.
    if not v.wait_line(4, 30):
        v.show(f"missing {action} overlap dialog")
        raise AssertionError(f"{action} overlap dialog did not wait; BASIC line {v.line()}")
    v.require_text("program will hit commander's routines!")
    v.require_text(f"{action}? y/n")
    v.keys(pet("n"))
    assert v.wait_line(10, 60)
    assert v.mem(0x97F0, 0x97F1) == before
v.quit()

print("PASS: BASIC 4.0 copy and LOAD/RUN overlap warnings use relocated helpers")
