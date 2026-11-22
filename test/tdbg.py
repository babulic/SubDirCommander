import time, sys
sys.path.insert(0, "/tmp/t")
from vice import *
v = Vice(d8="/tmp/t/fb38w.d64", d9="/tmp/t/big9.d64", warp=False)
time.sleep(3)
v.keys(pet('load"') + NAME38 + pet('",8\n'))
v.wait_text("ready.", 120); time.sleep(1)
v.keys(pet('run\n')); v.wait_line(5007, 60); time.sleep(0.5)
v.keys([ord('9'), RET]); v.wait_line(5170, 200)
v.key(RIGHT); v.key(RIGHT)
for i in range(7): v.key(DOWN)
print(v.screen()[9])
v.key(ord('7'), at=None)
seen=[]
t0=time.time()
while time.time()-t0 < 40:
    l=v.line()
    if not seen or seen[-1]!=l: seen.append(l)
    sc=v.screen()
    pass
print(seen)
v.show("now")
b=v.mem(0x277,0x280); print("kbuf", list(b), "n", v.mem(0xc6,0xc6)[0])
v.quit()
