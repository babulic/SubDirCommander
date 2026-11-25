# Codex review — SubDirCommander 4.0, follow-up 02

This is the authoritative review record for the current 4.0 release. It
includes the completed identifier shortening, dead-code removal and binary
trailer architecture where those facts affect the current artifacts.

## Resolved P1 — BASIC helpers now use a binary transport trailer

4.0 removes the helper bytes from BASIC `DATA`. The normal BASIC program ends
with `$0000`; the raw PRG appends a relocator followed by the three executable
helper images. The fourth protected region holds directory state at run time;
it is not an executable trailer image. The transport is not called in place.
In the current release the BASIC terminator ends at `$2916` and the trailer
starts at `$2917`.

Its first BASIC line starts with the direct-load reentry gate
`ON-SGN(RL)GOTO4489`; on an ordinary start it evaluates to zero and falls
through to this numeric bootstrap:

1. `POKE55,240:POKE56,151:CLR` — reserve the top of BASIC RAM at `$97F0`.
2. `POKE45,23:POKE46,41:CLR` — set `VARTAB` to the start of this build's
   trailer (`$2917`) and rebuild BASIC's allocation pointers below the ceiling.
3. `SYS10519` — call the still-unreferenced trailer relocator.

The second `CLR` is necessary. KERNAL has set `VARTAB` after the complete raw
PRG, including its trailer; changing only `MEMSIZ` would leave BASIC's future
allocations starting after that transport. `tools/build40.py` derives the
trailer address from the tokenized BASIC program and rejects a listing whose
literal `POKE45/46` or `SYS` no longer matches it.

`RL` is set immediately before a direct in-program `LOAD`. Such a load
re-enters BASIC at line 1; the gate resumes at 4489 instead of entering the
consumed raw trailer. On a normal startup the one scalar `RL` is created only
after KERNAL's raw-file end pointer, then the first `CLR` immediately discards
it; it cannot overwrite the transport before the helper copy.

The relocator copies the images before line 2 allocates any variables, arrays
or strings. The active map is:

| Service | Resident range | Entry |
| --- | --- | --- |
| `COPY HELPER` | `$97F0-$9879` | `SYS 38896` |
| `DIR HEADER/WORK` | `$9880-$98F2` | internal state |
| `KEY PANEL` | `$9930-$9B14` | `SYS 39216` |
| `DIR READ` | `$9B20-$9F6F` | `SYS 39712` |

`DIR HEADER/WORK` is fully resident: header `$9880-$989A`, workspace
`$98A0-$98F2`. This avoids the old high-build workspace crossing `$A000` into
BASIC ROM and ensures that a program loaded at `$C800` or `$C900` cannot
corrupt Commander state. The former `DATA` loader and hex decoder have no
4.0 caller and are not assembled, transported or distributed.

The 4.0 title renderer follows the 3.8 presentation rule: two inverse spaces,
the complete incoming header stream and one appended inverse space, truncated
to the 27 cells before the right-side panel. Thus the first 25 incoming header
characters are preserved unchanged; a device-supplied byte after `2A` remains
visible while the appended blank naturally falls outside the area. Only a
short header receives the appended blank within its 25 cells. `showhead` and
`I$` use the same stored value, so a fresh list and later Copy/Delete redraw
have identical attributes.
The tail of the fixed `DIR READ` reservation is intentional padding; the full
`$9B20-$9F6F` range remains unavailable to BASIC. There is no live BASIC
Commander code or state at `$C000-$CFFF`: `$C800` and `$C900` are safe direct
load targets.  The sole other high-RAM use is the temporary cross-drive Copy
buffer at `$A000-$BFFF`, behind BASIC ROM, and it is used only while Copy runs.

At a clean Commander exit, line 4990 writes an `RTS` at `VARTAB`, the former
raw trailer entry. During the first run BASIC correctly reuses that transport
RAM for variables; without this single-byte handoff a later ordinary `RUN`
would `SYS` into variable bytes and return to `READY`. The resident helpers
remain at `$97F0-$9FFF`, so the next `RUN` returns from this `RTS` and starts
normally. A confirmed operation that overwrites resident helpers remains an
explicitly unsupported return case.

Before commands `7` (Run) and `8` (Load), BASIC calculates a conservative
range from the PRG load address and its directory-block count. A PRG at
`$0801` is immediately handed to BASIC and receives no Commander warning:
it replaces the BASIC Commander. Every other overlap is checked against the
single continuous resident interval `$97F0-$9F6F` and shows `Program will hit
Commande's routines!` before asking `Run? y/n` or `Load? y/n`; any key other
than `y` cancels. A confirmed operation may alter the Commander, and it is
deliberately not silently reinstalled. The warning is still necessary: KERNAL
`LOAD` does not obey BASIC's memory ceiling.

## Resolved P2 — obsolete `M/m` key-map entries

The two former Make-directory mappings `77,0,205,0` were removed before the
remaining 31 keyboard/action pairs were compacted into one PETSCII string.
Make directory has long used `N/n`; `M/m` retain the initialized zero value
of every `K%(0..255)` entry after `DIM`, so they remain no-ops. The
structural verifier decodes the tokenized PETSCII literal and compares all 31
pairs byte-for-byte with the former map; it does not trust the textual
spelling of control or shifted keys.

## Resolved P2 — 41-block BASIC compaction

The BASIC V2 PRG now occupies 41 1541 blocks. The original `INPUT "Target
drive";U` statement exists once, in shared line 6, and is reached by Copy,
Move and marked-file Copy/Move. It therefore keeps the original prompt
spacing, cursor and C64 BASIC editor behavior; it is not a `GET` substitute.

Line 7 performs the identical `LEFT$(N$,16)` normalization for Rename, Copy
and Move. DOS status fields are held only while their status string is built,
using the existing numeric scratch variables `B`, `H` and `J`. The image-type
check similarly reuses `F`: every caller has consumed the parse result before
it calls line 3700, which replaces that value immediately.

The current shrink moves the binary transport to `$2917`; the line-1
`POKE45/46` and `SYS` literals are verified against the tokenized program by
both the builder and the artifact test.

## Resolved P2 — unused ML code and state

The ML audit found and removed only items with no direct or table reference:
the `cmdapp` and `strout` routines, plus `savelen` and the ten-byte `kbuf`.
`hex16` remains: it is the fall-through continuation of the used `hexsa`
entry. The assembly still aligns `bufstart` to `$2300`; the documented ML
copy-buffer contract is unchanged. `v40_ml_smoke.py` starts the released ML
PRG in VICE and asserts live cursor movement.

## Accepted limitation — BAS and ML can enter RAM hidden by ROM or I/O

With the normal `$01=$37` mapping, `$A000-$BFFF` is BASIC ROM,
`$D000-$DFFF` is I/O and `$E000-$FFFF` is KERNAL ROM.  Both frontends can
currently load into those addresses and then execute the visible ROM/I/O
bytes instead of the loaded RAM.

- BASIC line 4486 routes any start at or above `$A000` to direct `LOAD ...,1`.
- ML `ml/sdc40.asm` takes the direct path for any start at or
  above `$A000`, bypassing the later `$D000` check.

No runtime rejection or bank-switching trampoline will be added. The release
keeps the historic direct-load behaviour. The documented return contract is
therefore deliberately narrower: direct return is supported only from
`$2300-$9FFF` and `$C000-$CFFF`; callers that load elsewhere must hand
control to BASIC or make their own banking decision. `m8.py` probes `$D000`
but deliberately does not execute it.

## Resolved P2 items

### ML map, README and web

`README.md` and the web page now use the assembled `bufstart = $2300`, state
the 31.25 KiB `$2300-$9FFF` buffer, and document the direct-return contract:
only `$2300-$9FFF` and `$C000-$CFFF` are safe.  The ROM/I/O ranges remain a
documented accepted limitation above; documentation does not claim that the
current code safely executes them. The current 4.0 structural verifier keeps
the generated ML artifact and its documented address contract in sync.

### DOS delimiters

Both frontends refuse `:`, `,`, `=` and `"` before destructive DOS commands.
BASIC intentionally retains the original C64 `INPUT` editor and checks a
complete quoted input after it returns; ML checks both typed and listed names.

### Device integration harness

`test/DEVICE_MATRIX.md` is the command contract for SD2IEC, Pi1541 and Kung
Fu Flash. `test/run_device_matrix.sh` accepts an explicit firmware/emulator
adapter for every physical firmware target; without it it returns exit `77`
(`SKIP`), never a synthetic PASS. This repository currently has no firmware
adapter, so those cases are documented integration coverage, not completed
device-validation results.

## 4.0 binary-trailer release

`tools/build40.py`, `test/verify_artifacts40.py` and `test/run40.sh` passed.
The final runner report is `TEST_REPORT_SUB40.md`; it records the valid VICE
startup directory and preserved disk title, `$37/$38 = $97F0`, byte-exact
relocation of the three executable images and validation of the fourth reserved
directory-state range, clean Exit followed by ordinary RUN
and fresh drive selection, and a failed cross-drive Move (`FILE EXISTS`) that
preserves both files and redraws the title. It also records cross-drive Copy
through `SYS 38896`, and declined Load and Run of a synthetic nine-block
`$97F0` PRG. The latter overlaps the complete resident interval and the test
requires `Program will hit Commander's routines!` in both paths while
confirming that the first helper byte did not change.

The 4.0 runner replaces only its previous `basic40-binary-trailer` history
report under `test/reports/`.

## Remaining test debt

`test/run40.sh` fails on every shell, builder, artifact, VICE or assertion
failure. `verify_artifacts40.py` rejects a BASIC record longer than 200 bytes,
checks each helper range, the derived trailer address, boot literals, collision
range and the matching public documentation.

Still add asserted VICE coverage for:

1. ML cursor/page/highlight state after navigation;
2. full-disk/abort cleanup: no partial target and recovered free blocks;
3. NUL-containing SEQ cross-drive copy;
4. the affirmative `y` path for a deliberately destructive resident-overlap
   Load/Run operation;
5. relocation integrity after more varied Copy failure/abort paths, including
   preserved `MK%` marks.

VICE tests run in VICE console mode when executed outside the filesystem
sandbox, which must be allowed to create the loopback remote-monitor socket.
The normal sandbox cannot open that socket; a socket failure is not a pass.
Each VICE scenario now chooses its own loopback monitor port, so an interrupted
scenario cannot silently drive a stale emulator from a previous run.
