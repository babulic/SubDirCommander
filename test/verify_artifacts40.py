#!/usr/bin/env python3
"""Host-side structural checks for the SubDirCommander 4.0 BASIC release."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASIC_TEXT = ROOT / "basic" / "SubDirCommand.40.txt"
BASIC_PRG = ROOT / "dist" / "SubDirCommand.40.prg"
ML_PRG = ROOT / "dist" / "%SubDirCommand.40.prg"
TRAILER_PRG = ROOT / "build40" / "trailer40.prg"
HELPERS = (
    ("copyhelper", 0x97F0, 138),
    ("panel", 0x9930, 485),
    ("dirread", 0x9B20, 1104),
)
MEMTOP = 0x97F0
HEADER_START = 0x9880
HEADER_END = 0x98F2
RESIDENT_END = 0x9F6F


def basic_end(program: bytes) -> int:
    assert program[:2] == b"\x01\x08", "BASIC must load at $0801"
    offset = 2
    while True:
        next_line = int.from_bytes(program[offset : offset + 2], "little")
        if next_line == 0:
            return offset + 2
        end = program.index(0, offset + 4)
        assert 2 + next_line - 0x0801 == end + 1, "broken BASIC line link"
        offset = end + 1


def basic_line(program: bytes, wanted: int) -> bytes:
    """Return the token bytes of one numbered BASIC line."""
    offset = 2
    while True:
        next_line = int.from_bytes(program[offset : offset + 2], "little")
        if next_line == 0:
            break
        number = int.from_bytes(program[offset + 2 : offset + 4], "little")
        end = program.index(0, offset + 4)
        if number == wanted:
            return program[offset + 4 : end]
        offset = end + 1
    raise AssertionError(f"BASIC line {wanted} missing")


def directory(path: Path) -> str:
    return subprocess.check_output(
        ["c1541", "-attach", str(path), "-dir"], text=True, stderr=subprocess.STDOUT
    )


source = BASIC_TEXT.read_text(encoding="latin-1")
match = re.search(
    r"^\s*1\s+on-sgn\(rl\)goto4489:poke55,240:poke56,151:clr:poke45,(\d+):poke46,(\d+):clr:ifpeek\(38896\)<>169orpeek\(38898\)<>133thensys(\d+)\s*$",
    source,
    re.IGNORECASE | re.MULTILINE,
)
assert match, "line 1 must contain the direct-load gate and signature bootstrap"

program = BASIC_PRG.read_bytes()
end = basic_end(program)
trailer_address = 0x0801 + end - 2
vartab = int(match.group(1)) + 256 * int(match.group(2))
assert vartab == trailer_address
assert int(match.group(3)) == trailer_address
assert program[end:] == TRAILER_PRG.read_bytes()[2:], "raw trailer differs from assembler output"
assert trailer_address == 0x2C5D, f"unexpected BASIC/trailer boundary ${trailer_address:04X}"
assert (len(program) + 253) // 254 == 44, "BASIC release must fit in 44 blocks"

for old_sys in (828, 49152, 50432, 50608, 51200):
    assert f"sys{old_sys}" not in source.lower(), f"old helper SYS {old_sys} remains"
for old_line in range(5925, 6125):
    assert not re.search(rf"^\s*{old_line}\s", source, re.MULTILINE), "old DATA helper transport remains"

payloads = []
for name, start, size in HELPERS:
    payload = (ROOT / "build40" / f"{name}.bin").read_bytes()
    assert len(payload) == size, name
    payloads.append(payload)
assert payloads[0][0] == 169 and payloads[0][2] == 133, "restart signature no longer matches COPY HELPER"
assert program[end:].endswith(b"".join(payloads)), "trailer helper payload order differs"

build = (ROOT / "tools" / "build40.py").read_text()
assert "HELPER_WORK=39072" in build
assert "HELPER_HEADER=39040" in build
assert "TITLE_MARGIN=1" in build
assert "HELPER_WORK = 0" in (ROOT / "basic" / "dirread.asm").read_text()
assert "peek(39040+i)" in source.lower()
assert "51200+i" not in source
assert "HEX_DECODE" not in (ROOT / "basic" / "trailer40.asm").read_text()
assert "HEX DECODE" not in source
assert "gosub4420:ov=0:h=s+val(a$)*254:ifs=2049orh<38897ors>40815thenreturn" in source.lower()
assert "program will hit commander's routines!" in source.lower()
assert 'ifl$="cbm"orl$="cop"orl$="jif"thenopen1,d,15:gosub4000' not in source.lower()
assert '4302 ifp$="<"thenreturn' in source.lower()
assert '4303 ift$="dir"then4872' in source.lower()
assert '4304 poke646,1:gosub5:print"delete item ? y/n"' in source.lower()
assert '4271 ift$<>"dir"then4274' in source.lower()
assert '4241 x=d:d=u:od=0:o$="":l$="":gosub4250:e=(l$="cbm"orl$="cop"orl$="jif"):d=x:od=0' in source.lower()
assert '4812 ifx$=""andl$<>"cbm"andl$<>"cop"andl$<>"jif"thenx$="00"' in source.lower()
assert '4250 ifod=dthenpoke144,0:return' in source.lower()
assert '4251 open1,d,15,"x?":input#1,b,o$,w,j:ifst and146then4268' in source.lower()
assert '4268 gosub4110:printj$:close1:od=0:return' in source.lower()
# Validate falls from 4260 into the DOS V command, not into the OS-probe error exit.
assert re.search(r"^ 4260 [^\n]*\n 4263 ", source, re.M)
assert '4900 e=-1:j$="{rvon}no dirs!"+r$:gosub4150:return' in source.lower()
assert '4920 e=0:ifl$="kun"then4900' in source.lower()
assert 'gosub4547:ifethenreturn' in source.lower()
assert '2960 od=0:o$="":c$="cd:_":goto4494' in source.lower()
assert '4483 gosub3700:iffthenod=0:o$="":c$="cd:"+c$:goto4494' in source.lower()

# One exact map governs binary sources, BASIC checks and public docs.  The
# builder derives the trailer boundary from tokenized BASIC; these assertions
# make every independently written address fail together if it drifts.
assert MEMTOP == HELPERS[0][1]
assert HEADER_START == 0x9880 and HEADER_END == 0x98F2
assert RESIDENT_END == HELPERS[-1][1] + HELPERS[-1][2] - 1
trailer_source = (ROOT / "basic" / "trailer40.asm").read_text().lower()
assert "copy_dest = $97f0" in trailer_source
assert "panel_dest = $9930" in trailer_source
assert "dir_dest = $9b20" in trailer_source
for public in (ROOT / "README.md", ROOT / "CODE_REVIEW_CODEX_02.md", ROOT / "web" / "index.html"):
    text = public.read_text(encoding="utf-8").lower()
    for value in ("$2c5c", "$2c5d", "$97f0-$9879", "$9880-$98f2", "$9930-$9b14", "$9b20-$9f6f"):
        assert value in text, f"{public.name} is missing {value}"
    assert "program will hit commander's routines!" in text, f"{public.name} has stale warning text"
    assert "$2977" not in text and "$2978" not in text, f"{public.name} has stale trailer address"

ml_source = (ROOT / "ml" / "sdc40.asm").read_text()
assert "SD2IEC only" not in ml_source
assert "dosasync\n        jsr opencmd" in ml_source
assert "dosfolder\n        jsr dosasync" in ml_source
assert "dosasyncrelist\n        jsr dosasync" in ml_source
assert "jsr waitopen\n        bcs dfbad\n        lda #0\n        sta cmdlen\n        jsr doscmd" in ml_source
assert "opencmd\n        jsr waitopen\n        bcc opcmd\n        rts\nopcmd   lda #15" in ml_source
assert "\nprobe   " not in ml_source
assert "lda tdev\n        sta dev\n        jsr waitopen\n        bcs xtargetbad" in ml_source
assert "No folders on KFF !" in ml_source
assert "rootpair\n        lda cbmdrv" in ml_source
assert "rootok  lda cbmdrv" in ml_source
assert "isdir   lda type" in ml_source
assert (
    'cdup    jsr cmdi\n        .text "cd:"\n        .byte $5f, 0'
    '            ; CD:\u2190  (left arrow, parent directory)\n'
    '        lda #0                  ; CD changes the DOS context, not the device.\n'
    '        sta oslen               ; Do not reuse an image\'s cached CBM title.\n'
    '        jmp dosfolder'
) in ml_source
assert (
    '        jsr cmdname\n'
    '        lda #0                  ; mounted image: refresh the firmware title\n'
    '        sta oslen\n'
    '        jmp dosfolder'
) in ml_source

# IEC directory records carry a fixed 16-byte filename.  The readers must
# preserve it exactly; FAT long-name recovery is a firmware concern, not one
# the Commander can safely guess from an 8.3 alias.
basic_dirread = (ROOT / "basic" / "dirread.asm").read_text()
assert "cpx #16\n        bcs nn\n        sta nbuf,x" in basic_dirread
assert "wn      cpx #16" in basic_dirread
assert "cpy #16\n        bcs -\n        sta namebuf,y" in ml_source
assert "sta idbuf\n        sta idbuf+1" in ml_source
assert "askover lda #0" in ml_source
assert 'overpre .null "Rewrite target "' in ml_source
assert 'overpost\n        .null "? y/n"' in ml_source
assert "jsr putwide            ; full 40 cells fit a 16-char target + y/n" in ml_source
assert "lda #4                 ; xtarget reopens the target command channel.\n        jsr CLOSE" in ml_source
assert "cmp #63\n        bne xfail" in ml_source
assert '        .null "3 RenameFl/Fd"' in ml_source
assert '        .null "6 DeleteFl/Fd"' in ml_source

# The 29 keyboard/action pairs are stored compactly, not in BASIC DATA.  Read
# them from the tokenized literal, not merely the source notation: PETSCII
# upper/lower case has different byte values and N/n still share the folder key.
KEYMAP = (
    17, 1, 145, 2, 29, 3, 157, 4, 49, 5, 133, 5, 50, 6, 137, 6,
    51, 7, 134, 7, 52, 8, 138, 8, 53, 9, 135, 9, 54, 10, 139, 10,
    55, 11, 136, 11, 13, 11, 56, 12, 140, 12, 57, 13, 48, 14,
    78, 17, 206, 17, 94, 16, 32, 19, 42, 20,
    95, 21,
)
body = basic_line(program, 5920)
strings: list[bytes] = []
start = None
for index, value in enumerate(body):
    if value != 0x22:
        continue
    if start is None:
        start = index + 1
    else:
        strings.append(body[start:index])
        start = None
assert start is None and len(strings) == 4, "unexpected key-map literal shape"
encoded = (
    strings[1] + bytes((13,)) + strings[2] + bytes((206,)) + strings[3]
)
assert len(encoded) == 58
decoded: list[int] = []
for index in range(0, len(encoded), 2):
    decoded.extend((encoded[index], encoded[index + 1] - 64))
assert tuple(decoded) == KEYMAP, "tokenized key map differs from the 29 commands"
assert "fori=1to58step2:k%(asc(mid$(k$,i,1)))=asc(mid$(k$,i+1,1))-64:next" in source.lower()
assert not re.search(r"^\s*(?:2980|4870)\s", source, re.MULTILINE), "obsolete R-folder key path remains"
numbers = re.findall(r"^\s*(\d+)\s", source, re.MULTILINE)
assert len(numbers) == len(set(numbers)), "BASIC source has duplicate line numbers"
assert not re.search(r"^\s*\d+\s+data", source, re.IGNORECASE | re.MULTILINE)
assert source.lower().count('input"target drive";u') == 1
assert source.lower().count("gosub6") == 3
assert source.lower().count("gosub7") == 3

for image in (ROOT / "dist" / "SubDirCommand.40.d64", ROOT / "dist" / "fb.d64"):
    listing = directory(image)
    assert "SubDirCommand.40" in listing, image
    assert "%SubDirCommand40" in listing, image
assert ML_PRG.exists() and ML_PRG.stat().st_size > 2
for name in ("SubDirCommand.40.prg", "%SubDirCommand.40.prg", "SubDirCommand.40.d64", "fb.d64"):
    published = ROOT / "web" / "public" / "files" / name
    assert published.read_bytes() == (ROOT / "dist" / name).read_bytes(), f"web copy of {name} is stale"

print(f"PASS: 4.0 BASIC ends at ${trailer_address:04X}; binary trailer and media are exact")
