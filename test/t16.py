"""BASIC Copy transfers a file selected with Space to the other drive."""

import sys

sys.path.insert(0, "/tmp/t")
sys.path.insert(0, __import__("pathlib").Path(__file__).parent.as_posix())
from d64 import D64
from vice import DOWN, RET, pet, start


v = start("/tmp/t/fb39w.d64", d9="/tmp/t/big9.d64", drive=ord("9"))
for _ in range(5):
    v.key(DOWN)

# Space marks FILE05 and moves the cursor to the following entry.  Copy must
# use the marked FILE05, not the cursor's new location or an empty name.
v.key(ord(" "))
v.key(ord("4"), at=10)
assert v.wait_line(4620, 30)
v.keys(pet("8") + [RET])
assert v.wait_line(10, 600)
v.quit()

source = D64("/tmp/t/big9.d64").read(b"FILE05")
target = D64("/tmp/t/fb39w.d64").read(b"FILE05")
assert source is not None
assert target == source
print("PASS: BASIC copies a Space-marked file cross-drive")
