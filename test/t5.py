import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb39.d64", d9="/tmp/t/big9.d64", drive=ord('9'))
def hl():
    rv = v.rev_rows(); sc = v.screen()
    rows = [r for r in range(2,24) if rv[r] > 10]
    return [(r, sc[r][:24].strip()) for r in rows]

def expect(row, name):
    assert v.highlighted_row() == row
    assert name in v.screen()[row], (row, name, v.screen()[row])

expect(2, "file00")
for i in range(3): v.key(DOWN)
expect(5, "file03")
v.key(RIGHT); expect(5, "file25")
v.key(RIGHT); expect(5, "file47")
v.key(RIGHT); expect(18, "blocks free")
v.key(UP); expect(17, "oxford pascal")
v.key(DOWN); v.key(DOWN); expect(18, "blocks free")
v.key(LEFT); expect(18, "file38")
v.key(LEFT); expect(18, "file16")
v.key(LEFT); expect(2, "file00")
v.key(UP); expect(2, "file00")
v.key(LEFT); expect(2, "file00")
for i in range(21): v.key(DOWN)
expect(23, "file21")
v.key(DOWN); expect(2, "file22")
v.key(UP); expect(23, "file21")
v.show("final")
v.shot("/tmp/t/s39_big.png")
v.quit()
print("PASS: BASIC navigation keeps the expected cursor and highlighted entry")
