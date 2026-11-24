import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = start("/tmp/t/fb39w.d64")
v.key(ord('2'), at=None)
lines=set(); t0=time.time()
while time.time()-t0 < 120:
    l=v.line(); lines.add(l)
    if l==10 and time.time()-t0>3: break
    time.sleep(0.3)
print("validate visited 5007 (drive prompt)?", 5007 in lines, "now", v.line())
for i in range(13): v.key(DOWN)
v.key(ord('3'), at=10); v.wait_line(4273, 30); time.sleep(0.3)
# Native INPUT must retain C64 screen editing: replace the final x by moving
# left and typing y, yielding the valid new name "joy".
v.keys(pet("jox")+[LEFT]+pet("y")+[RET]); v.wait_line(10, 120); time.sleep(1)
print("after rename:", v.screen()[15][:27])
v.key(ord('5'), at=10); time.sleep(2)
print("start adr:", v.screen()[15][:27])
v.key(ord('6'), at=10); v.wait_line(4302, 30); time.sleep(0.5)
print("confirm:", v.screen()[15][:27])
v.keys(pet("y")); v.wait_line(10, 120); time.sleep(1)
print("after delete:", v.screen()[15][:27])
v.key(ord('_'), at=10); time.sleep(2)
print("exit: line", v.line(), "repeat", v.mem(0x28a,0x28a)[0], "screen0", repr(v.screen()[0]))
v.quit()
