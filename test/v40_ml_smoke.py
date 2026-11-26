"""Start the current ML frontend and assert live list navigation in VICE."""

import os
import shutil
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
from d64 import D64, name_str
from vice import DOWN, mlstart, pet


v = mlstart(str(ROOT / "dist" / "SubDirCommand.40.d64"), drive=ord("8"))
v.require_text("subdir commander")
v.require_text("numeric keys:")
v.require_text("renamefl/fd")
v.require_text("deletefl/fd")
v.require_text("new/formdsk")
panel = [line[27:].lower() for line in v.screen()]
assert "crsr keys" in panel[15]
assert "other keys" in panel[18]
assert not panel[23].strip() and not panel[24].strip()
first = v.highlighted_row()
v.mkey(DOWN)
assert v.highlighted_row() == first + 1
v.quit()

# The drive probe before a DOS command must not drop the queued command:
# Validate removes an unclosed (splat) file, Delete scratches the first file.
work = Path(os.environ["SDC40_WORK"])
image_path = work / "mlvalid.d64"
shutil.copy2(work / "source.d64", image_path)
image = D64(str(image_path))
for (track, sector, index), entry in image.entries():
    if entry[2] & 0x80 and name_str(entry[5:21]) == "turbo ii":
        block = bytearray(image.sec(track, sector))
        block[index * 32 + 2] &= 0x7F
        image.setsec(track, sector, bytes(block))
        break
else:
    raise AssertionError("turbo ii fixture entry not found")
image.save()
v = mlstart(str(ROOT / "dist" / "SubDirCommand.40.d64"), d9=str(image_path), drive=ord("9"))
v.mkey(ord("2"))
time.sleep(1)
assert not any("turbo ii" in row.lower() for row in v.screen()), "ML Validate kept the splat file"
v.mkey(ord("6"))
v.mkey(pet("y")[0])
v.quit()
names = [name_str(entry[5:21]) for _, entry in D64(str(image_path)).entries() if entry[2]]
assert "turbo ii" not in names, "ML Validate did not send V"
assert "!ultraload plus" not in names, "ML Delete did not send S:"
print("PASS: ML 4.0 starts, navigates, validates and deletes in VICE")
