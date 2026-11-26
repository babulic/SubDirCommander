"""Assert that BASIC 4.0 relocates its binary trailer before allocating RAM."""

import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "test"))
from vice import start, pet


NAME40 = [0xD3] + pet("ub") + [0xC4] + pet("ir") + [0xC3] + pet("ommand.40")
HELPERS = (
    ("copyhelper", 0x97F0),
    ("panel", 0x9930),
    ("dirread", 0x9B20),
)


v = start(str(ROOT / "dist" / "SubDirCommand.40.d64"), name=NAME40)
assert v.wait_line(10, 60)
v.require_text("subdircommand.40")
v.require_text("subdir commander")
v.require_text("blocks free")
v.require_text("numeric keys:")
v.require_text("renamefl/fd")
v.require_text("deletefl/fd")
v.require_text("new/formdsk")
panel = [line[27:].lower() for line in v.screen()]
assert "crsr keys" in panel[15]
assert "other keys" in panel[18]
assert not panel[23].strip() and not panel[24].strip()
header = v.mem(0x9880, 0x989A)
assert b"SUBDIR COMMANDER" in header, header.hex()
assert header[24] == 0x20, header.hex()
# The title reserves two reverse-space cells, then has exactly 25 header cells
# before the right-hand panel.
assert v.mem(0x0428, 0x0429) == b"\xa0\xa0"
assert v.mem(0x0442, 0x0442) == b"\xa0"

# Line 1 must have lowered BASIC's allocation ceiling before the trailer ran.
assert v.mem(0x37, 0x38) == bytes((0xF0, 0x97))
source = (ROOT / "basic" / "SubDirCommand.40.txt").read_text(encoding="latin-1")
match = re.search(
    r"poke45,(\d+):poke46,(\d+):clr:ifpeek\(38896\)<>169orpeek\(38898\)<>133thensys(\d+)",
    source,
    re.IGNORECASE,
)
assert match, "missing VARTAB/signature/SYS bootstrap"
trailer_address = int(match.group(1)) + 256 * int(match.group(2))
assert int(match.group(3)) == trailer_address
assert int.from_bytes(v.mem(0x2D, 0x2E), "little") == trailer_address
for pointer in (0x2D, 0x2F, 0x31):
    value = int.from_bytes(v.mem(pointer, pointer + 1), "little")
    assert value < 0x97F0, hex(value)

# The exact assembled helper images must now be resident at the planned map.
for name, address in HELPERS:
    payload = (ROOT / "build40" / f"{name}.bin").read_bytes()
    actual = v.mem(address, address + len(payload) - 1)
    if actual != payload:
        changed = [index for index, pair in enumerate(zip(actual, payload)) if pair[0] != pair[1]]
        print(name, "runtime changes", changed[:20], "count", len(changed))
    assert actual == payload, name

# BASIC variables intentionally consume the raw trailer.  A regular RUN must
# therefore trust the two-byte signature of the relocated COPY HELPER, not
# execute those raw bytes.  Corrupt the old transport explicitly to cover the
# same path as a RUN/STOP interruption that bypasses line 4990.
v.key(0x5F, at=10)
assert v.wait_text("ready.", 60)
v.poke(trailer_address, [0, 0, 0])
v.keys(pet("run\n"))
assert v.wait_line(5007, 120)
v.keys(pet("8") + [13])
assert v.wait_line(10, 120)
v.require_text("subdircommand.40")

v.quit()
print("PASS: BASIC 4.0 relocates helpers and restarts after consumed trailer")
