"""Start the current ML frontend and assert live list navigation in VICE."""

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
from vice import DOWN, mlstart


v = mlstart(str(ROOT / "dist" / "SubDirCommand.40.d64"), drive=ord("8"))
v.require_text("subdir commander")
v.require_text("numeric keys:")
first = v.highlighted_row()
v.mkey(DOWN)
assert v.highlighted_row() == first + 1
v.quit()
print("PASS: ML 4.0 starts and navigates a directory in VICE")
