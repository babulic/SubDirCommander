"""Assert the ML buffer boundary fixtures and DOS-name rejection."""

import sys
import time
from pathlib import Path

sys.path.insert(0, "/tmp/t")
sys.path.insert(0, Path(__file__).parent.as_posix())
from d64 import D64
from vice import *


def goto(v, name):
    for _ in range(120):
        row = v.highlighted_row()
        if name in v.screen()[row]:
            return
        v.mkey(DOWN)
    raise AssertionError(f"did not find {name}")


def start_bounds():
    return mlstart("/tmp/t/fbmlw.d64", d9="/tmp/t/bounds9.d64", drive=ord("9"))


def direct(v, name):
    goto(v, name)
    v.mkey(ord("7"))
    v.require_text("Ran OK")
    v.mkey(ord(" "))
    assert v.idle(30)


# $22ff is below bufstart: the ML frontend must hand it to BASIC.
v = start_bounds()
goto(v, "b22ff")
v.enter(); v.cmd("> 0277 37", wait=0.15); v.cmd("> 00c6 01", wait=0.15); v.go()
assert v.wait_text("ready.", 60)
v.require_text("sys8959")
v.quit()

# Exact safe execution boundaries are direct ML calls and must return.  Keep
# one session for these four cases: each successful RTS returns to the list.
v = start_bounds()
for boundary in ("b2300", "b9fff", "bc000", "bcfff"):
    direct(v, boundary)

# $d000 is I/O in the default mapping.  P1 explicitly keeps its direct-run
# refusal as follow-up work, so this test probes the address only, never runs
# a fixture there.
goto(v, "bd000")
v.mkey(ord("5"))
v.require_text("Start From: 53248")
v.quit()

# A raw delimiter in a listed name cannot be used destructively.
v = start_bounds()
goto(v, "bad:name")
v.mkey(ord("6"))
assert v.idle(30)
v.quit()
assert D64("/tmp/t/bounds9.d64").read(b"BAD:NAME") is not None
print("PASS: ML boundaries and DOS-name protection")
