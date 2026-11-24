"""BASIC frontend rejects a typed DOS-command delimiter without mutation."""

import sys

sys.path.insert(0, "/tmp/t")
sys.path.insert(0, __import__("pathlib").Path(__file__).parent.as_posix())
from d64 import D64
from vice import *


def selected(v, name):
    for _ in range(40):
        if name in v.screen()[v.highlighted_row()]:
            return
        v.key(DOWN)
    raise AssertionError(f"did not find {name}")


v = start("/tmp/t/fb39w.d64")
selected(v, "joyst")
assert v.wait_line(4, 10)
v.key(ord("3"), at=None)
assert v.wait_line(4390, 30)
v.keys(pet("bad:name") + [RET])
assert v.wait_line((4, 2990), 30)
v.key(ord(" "), at=(4, 2990))
assert v.wait_line((4, 10), 60)
v.quit()

disk = D64("/tmp/t/fb39w.d64")
assert disk.read(b"JOYST. PORTS TST") is not None
assert disk.read(b"BAD:NAME") is None
print("PASS: BASIC rejects typed DOS delimiters")
