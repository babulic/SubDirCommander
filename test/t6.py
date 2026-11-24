import time, sys
sys.path.insert(0, "/tmp/t")
sys.path.insert(0, __import__("pathlib").Path(__file__).parent.as_posix())
from d64 import D64
from vice import *
v = start("/tmp/t/fb39w.d64", d9="/tmp/t/big9.d64", drive=ord('9'))

def copy(name, drive):
    v.key(ord('4'), at=10)
    v.wait_line((4340,4390), 60); time.sleep(0.3)
    v.keys(pet(name)+[RET])
    v.wait_line(4341, 30); time.sleep(0.3)
    v.keys(pet(drive)+[RET])
    t0=time.time()
    v.wait_line(10, 600); time.sleep(1)
    return time.time()-t0
for i in range(5): v.key(DOWN)
before = D64("/tmp/t/fb39w.d64").blocks_free()
source_disk = D64("/tmp/t/big9.d64")
source = source_disk.read(b"FILE05")
assert source is not None
source_loc, source_entry = source_disk.find(b"FILE05")
assert source_loc and source_entry
source_blocks = len(source_disk.chain(source_entry[3], source_entry[4]))
print("cross copy file05 -> 8 took", copy("", "8"))
print("copy again took", copy("", "8"))
assert v.wait_text("63, file exists", 60)
v.show("copy again -> expect 63 file exists")
v.shot("/tmp/t/s39_exists.png")
v.quit()
target = D64("/tmp/t/fb39w.d64")
assert target.read(b"FILE05") == source
assert target.blocks_free() == before - source_blocks
same_name = sum(
    bytes(entry[5:21]).rstrip(b"\xa0") == b"FILE05"
    for _, entry in target.entries()
)
assert same_name == 1, same_name
print("PASS: BASIC cross-drive copy is byte-exact and duplicate-safe")
