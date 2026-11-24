# Codex review — SubDirCommander 4.0, follow-up 02

This is the authoritative record of the remaining review items after the
BASIC optimization in `CODE_REVIEW_CODEX.md` and the 4.0 implementation. It
deliberately excludes the completed identifier shortening, dead assignments
and tokenized-line length guard.

## Resolved P1 — BASIC helpers now use a binary transport trailer

4.0 removes the helper bytes from BASIC `DATA`. The normal BASIC program ends
with `$0000`; the raw PRG appends a relocator followed by the three executable
helper images. The fourth protected region holds directory state at run time;
it is not an executable trailer image. The transport is not called in place.

Its first BASIC line starts with the direct-load reentry gate
`ON-SGN(RL)GOTO4489`; on an ordinary start it evaluates to zero and falls
through to this numeric bootstrap:

1. `POKE55,240:POKE56,151:CLR` — reserve the top of BASIC RAM at `$97F0`.
2. `POKE45,120:POKE46,43:CLR` — set `VARTAB` to the start of this build's
   trailer (`$2B78`) and rebuild BASIC's allocation pointers below the ceiling.
3. `SYS11128` — call the still-unreferenced trailer relocator.

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
corrupt Commander state. `DATA SKIP` was only the 3.9 loader for the discarded
helper `DATA`; it has no 4.0 caller and is no longer transported. `HEX DECODE`
was likewise used only to construct those 3.9 helper bytes, so it is neither
assembled, transported nor called in 4.0.

The 4.0 title renderer follows the 3.8 presentation rule: two inverse spaces,
the complete incoming header stream and one appended inverse space, truncated
to the 27 cells before the right-side panel. Thus the first 25 incoming header
characters are preserved unchanged; a device-supplied byte after `2A` remains
visible while the appended blank naturally falls outside the area. Only a
short header receives the appended blank within its 25 cells. `showhead` and
`I$` use the same stored value, so a fresh list and later Copy/Delete redraw
have identical attributes. The 3.9 source path retains its original title
renderer.
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
range from the PRG load address and its directory-block count. On an overlap
it lists every exact affected service and asks `Run anyway? y/n` or `Load
anyway? y/n`; any key other than `y` cancels. A confirmed operation may alter
the Commander, and it is deliberately not silently reinstalled. The warning
is still necessary: KERNAL `LOAD` does not obey BASIC's memory ceiling.

## Resolved P2 — obsolete `M/m` key-map entries

The two former Make-directory mappings `77,0,205,0` were removed from the
remaining BASIC key-map `DATA`. Make directory has long used `N/n`; `M/m`
were explicitly assigned action zero, exactly the initialized value of every
`K%(0..255)` entry after `DIM`. No code writes those two map entries or treats
action zero as a command. The initialization now reads the remaining 31
pairs, so pressing `M/m` still has the same no-op behaviour without storing
redundant data.

## Accepted limitation — BAS and ML can enter RAM hidden by ROM or I/O

With the normal `$01=$37` mapping, `$A000-$BFFF` is BASIC ROM,
`$D000-$DFFF` is I/O and `$E000-$FFFF` is KERNAL ROM.  Both frontends can
currently load into those addresses and then execute the visible ROM/I/O
bytes instead of the loaded RAM.

- BASIC line 4486 routes any start at or above `$A000` to direct `LOAD ...,1`.
- ML `ml/sdc39.asm` lines 906–908 take the direct path for any start at or
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
current code safely executes them.

`mkdisks.sh` creates exact `$22FF`, `$2300`, `$9FFF`, `$C000`, `$CFFF` and
`$D000` PRGs. `verify_fixtures.py` validates every load address; `m8.py`
asserts the `$22FF` handoff, direct return at the four safe boundaries and
the `$D000` start-address probe. It deliberately does not execute `$D000`,
which is outside the supported direct-return contract.

### DOS delimiters

Both frontends now refuse `:`, `,`, `=` and `"` before destructive DOS
commands. BASIC intentionally retains the original C64 `INPUT` editor and
checks a complete quoted input after it returns; ML checks both typed and
listed names. `t15.py` asserts that BASIC refuses quoted `"bad:name"` and
preserves the source file; `m8.py` uses a raw `BAD:NAME` directory fixture to
cover the ML listed-name path.

### Device integration harness

`test/DEVICE_MATRIX.md` is the command contract for SD2IEC, Pi1541 and Kung
Fu Flash. `test/run_device_matrix.sh pi1541-d64` runs a concrete VICE
true-drive D64 suite. The SD2IEC, Pi1541 SD-card and Kung Fu Flash modes take
an explicit firmware/emulator adapter; without it they return exit `77`
(`SKIP`), never a synthetic PASS. This repository currently has no such
firmware adapter, so the latter three are documented integration coverage,
not completed device-validation results.

## Release verification — 2026-11-24

`tools/build.sh`, `test/verify_artifacts.py`, `test/verify_fixtures.py` and
`test/verify_device_matrix.py` passed. The complete `test/runall.sh` BASIC
and ML VICE suite also passed with exit status 0, including the asserted
`t5.py`, `t6.py`, `t15.py` and `m8.py` coverage. This is true-drive D64
coverage; it is not a firmware-level PASS for SD2IEC, Pi1541 SD-card mode or
Kung Fu Flash, which remain explicit adapter-dependent `SKIP`s.

The official full-suite, single-scenario and device-matrix runners regenerate
`TEST_REPORT_SUB39.md` and save a timestamped copy under `test/reports/` in
their `EXIT` handlers. A later failure or missing device adapter therefore
replaces an earlier PASS in the latest report. Reports carry a human-readable
test name, purpose and execution description. Before a run, the runner cleans
only prior reports in its own category (full suite, single scenario or device
matrix), preserving current reports from the other two categories.

### 4.0 binary-trailer release

`tools/build40.py`, `test/verify_artifacts40.py` and `test/run40.sh` passed.
The final runner report is `TEST_REPORT_SUB40.md`; it records the valid VICE
startup directory and preserved disk title, `$37/$38 = $97F0`, byte-exact
relocation of the three executable images and validation of the fourth reserved
directory-state range, clean Exit followed by ordinary RUN
and fresh drive selection, and a failed cross-drive Move (`FILE EXISTS`) that
preserves both files and redraws the title. It also records cross-drive Copy
through `SYS 38896`, and declined Load and Run of a synthetic nine-block
`$97F0` PRG. The latter overlaps the complete resident interval and the test
requires all four exact service names in both dialogs while confirming that
the first helper byte did not change.

The 4.0 runner replaces only its previous
`basic40-binary-trailer` history report under `test/reports/`. Its current
timestamped PASS is therefore separate from the 3.9 full-suite, scenario and
device reports.

## Remaining test debt

`test/runall.sh` correctly fails on shell/Python/fixture errors, and
`verify_artifacts.py` now also rejects a BASIC record longer than 200 bytes.
The asserted VICE coverage includes BASIC cursor/page movement (`t5.py`),
byte-exact cross-drive PRG copy plus duplicate protection (`t6.py`), typed
quoted-DOS-delimiter rejection (`t15.py`), and ML address/name boundaries
(`m8.py`). `t16.py` additionally asserts cross-drive Copy of a file marked
with Space; it guards the restored direct marked-name copy path in BASIC line
4627.
Other scenarios still only print screen/memory observations and can return
success after a wrong result.

Still add asserted VICE coverage for:

1. ML cursor/page/highlight state after navigation;
2. full-disk/abort cleanup: no partial target and recovered free blocks;
3. NUL-containing SEQ cross-drive copy;
4. BASIC `VARTAB`/`TXTTAB` after Load/Run and restored key-repeat on exit;
5. the affirmative `y` path for a deliberately destructive resident-overlap
   Load/Run operation;
6. relocation integrity after more varied Copy failure/abort paths, including
   preserved `MK%` marks.

VICE tests run in VICE console mode when executed outside the filesystem
sandbox, which must be allowed to create the loopback remote-monitor socket.
The normal sandbox cannot open that socket; a socket failure is not a pass.
Each VICE scenario now chooses its own loopback monitor port, so an interrupted
scenario cannot silently drive a stale emulator from a previous run.
