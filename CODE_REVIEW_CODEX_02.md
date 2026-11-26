# Codex review — SubDirCommander 4.0, follow-up 02

This is the authoritative review record for the current 4.0 release. It
includes the completed identifier shortening, dead-code removal and binary
trailer architecture where those facts affect the current artifacts.

## Resolved P1 — BASIC helpers now use a binary transport trailer

4.0 removes the helper bytes from BASIC `DATA`. The normal BASIC program ends
with `$0000`; the raw PRG appends a relocator followed by the three executable
helper images. The fourth protected region holds directory state at run time;
it is not an executable trailer image. The transport is not called in place.
In the current release the BASIC terminator ends at `$2DB1` and the trailer
starts at `$2DB2`.

Its first BASIC line starts with the direct-load reentry gate
`ON-SGN(RL)GOTO4489`; on an ordinary start it evaluates to zero and falls
through to this numeric bootstrap:

1. `POKE55,240:POKE56,151:CLR` — reserve the top of BASIC RAM at `$97F0`.
2. `POKE45,178:POKE46,45:CLR` — set `VARTAB` to the start of this build's
   trailer (`$2DB2`) and rebuild BASIC's allocation pointers below the ceiling.
3. On a mismatch of `PEEK(38896)=169` and `PEEK(38898)=133`, call
   `SYS11698`; those two bytes are the signature of the relocated COPY
   HELPER. A match naturally falls through to line 2 without executing the
   consumed transport.

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

During the first run BASIC correctly reuses raw trailer RAM for variables.
Line 1 therefore no longer relies on clean exit writing an `RTS` at `VARTAB`:
after `RUN/STOP`, RESTORE or a command that returns to BASIC, the relocated
COPY HELPER signature makes the next ordinary `RUN` skip the consumed trailer.
The fresh file image has no such helper signature, so it relocates before line
2. A confirmed operation that overwrites resident helpers remains an
explicitly unsupported return case.

Before commands `7` (Run) and `8` (Load), BASIC calculates a conservative
range from the PRG load address and its directory-block count. A PRG at
`$0801` is immediately handed to BASIC and receives no Commander warning:
it replaces the BASIC Commander. Every other overlap is checked against the
single continuous resident interval `$97F0-$9F6F` and shows `Program will hit
Commander's routines!` before asking `Run? y/n` or `Load? y/n`; any key other
than `y` cancels. A confirmed operation may alter the Commander, and it is
deliberately not silently reinstalled. The warning is still necessary: KERNAL
`LOAD` does not obey BASIC's memory ceiling.

## Resolved P2 — obsolete `M/m` key-map entries

The two former Make-directory mappings `77,0,205,0` and the obsolete `R/r`
remove-folder mappings were removed before the remaining 29 keyboard/action
pairs were compacted into one PETSCII string.
Make directory has long used `N/n`; `M/m` retain the initialized zero value
of every `K%(0..255)` entry after `DIM`, so they remain no-ops. The
structural verifier decodes the tokenized PETSCII literal and compares all 29
pairs byte-for-byte with the former map; it does not trust the textual
spelling of control or shifted keys.

## Resolved P2 — BASIC compaction and current feature budget

The BASIC V2 PRG currently occupies 44 1541 blocks. The original `INPUT "Target
drive";U` statement exists once, in shared line 6, and is reached by Copy,
Move and marked-file Copy/Move. It therefore keeps the original prompt
spacing, cursor and C64 BASIC editor behavior; it is not a `GET` substitute.

Line 7 performs the identical `LEFT$(N$,16)` normalization for Rename, Copy
and Move. DOS status fields are held only while their status string is built,
using the existing numeric scratch variables `B`, `H` and `J`. The image-type
check similarly reuses `F`: every caller has consumed the parse result before
it calls line 3700, which replaces that value immediately.

The active feature set moves the binary transport to `$2DB2`; the line-1
`POKE45/46`, signature and `SYS` literals are verified against the tokenized
program by both the builder and the artifact test.

## Resolved P1 — KFF command path and folder errors

The ML command path used a low-level `LISTEN`/`SECOND $6F` probe before every
command-channel `OPEN`. Kung Fu Flash lists successfully but does not accept
that empty secondary-address probe, so Copy, Move, Rename, Delete, Validate
and Format could incorrectly stop at `Device is not present !`. The raw probe
is replaced with the same normal command-channel `OPEN/CLOSE` preflight as
BASIC, followed by the actual command.

`MD:` and `RD:` are asynchronous on SD2IEC and Pi1541. Both frontends now
wait for the command channel to become available and then read its status
before relisting. A failed Pi1541 `RD:` consequently reports its real DOS
error instead of silently redrawing the unchanged list. Kung Fu Flash exposes
no MD/RD implementation and gives no usable error for it; the narrow `KUN`
OS tag therefore reports a folder-unavailable message without applying any SD2IEC/Pi1541
classification or capability gate.

Pi1541 `N:` is asynchronous too: both frontends now close the formatting
command, wait for a normal command-channel open and only then fetch final
status. This avoids waiting forever at `Formatting ...` after the new D64 was
already created.

## Resolved P1 — root files, folders and duplicate targets

`RO` had incorrectly meant both “enter this item with `CD:`” and “do not
modify this item.” A root `.D64`, `.D41`, `.D71`, `.D81`, `.DNP`, `.M2I`, `.G64` or `.T64` is openable, but is
still a file when shown at an SD2IEC/pi1541/KFF root. BAS now distinguishes
the actual `DIR` type from an image extension; ML has the explicit `ISDIR`
test. `3` therefore renames a file/image or a root-level folder, while `6`
uses `S:` for a file/image and `RD:` for the selected folder. Marking remains
file-only, so a marked Delete stays a file batch and never sends an accidental
batch `RD:`.

There is no firmware-name/version capability guess. BAS uses the already-read
three-character OS header and ML's identical `CBMDRV` classification:
`CBM`, `COP` and `JIF` mean a mounted disk/image; any other response is a
virtual-device root. On a root-file cross-device Copy/Move, the target is
queried with the same `X?`/`UI` sequence and must also be a root. The source
context is explicitly invalidated afterwards so the next list refreshes it.
That invalidation now occurs in both directions: when entering an image and
when `CD:` + left-arrow leaves it. BAS clears its `OD` status cache before
the subsequent `X?`/`UI`; ML clears `OSLEN`, which makes `GETOS` obtain the
new device header rather than reusing the previous `CBM DOS` string.

The directory-name contract remains the standard fixed 16-character field;
neither frontend tries to reconstruct a host filesystem long filename. This
is important at SD2IEC/Kung Fu Flash roots. SD2IEC's directory writer copies
16 name bytes and its FAT layer selects the short FAT name when the long name
cannot be represented; Kung Fu Flash/Kung Fu Flash 2 likewise select an
alternate short name for input longer than 16 characters and pad it to 16.
Thus a visible PETSCII graphics glyph may be the device's `~` in an alias
such as `NAME56~1.D64`, not a character introduced by Commander. The exact
alias is retained for display and every later command because expanding it
would address a name the device never supplied. Sources:
[SD2IEC](https://github.com/thierer/sd2iec),
[Kung Fu Flash](https://github.com/KimJorgensen/KungFuFlash), and
[Kung Fu Flash 2](https://github.com/KimJorgensen/KungFuFlash2).

`FILE EXISTS` no longer ends Copy/Move as a generic failure. Both frontends
ask at that point only; `Y` scratches the target and retries the one command,
while any other key skips that item. A cross-device Move scratches the source
only after the replacement copy completed. The constrained 27-cell ML message
shows `Rewrite target? y/n`; the selected row and typed target identify it.

Format labels now say `Disk name`, `Disk ID` and `New disk on drive`. An empty
ID at a virtual root becomes `00`, yielding `N:<name>,00` for pi1541. At a
mounted disk `CBMDRV`/the BAS header says disk mode, so blank remains the
existing bare `N:<name>` quick format.

The BASIC initial drive query now follows the same rule: its first operation
is the real `X?` command-channel request, with its own I/O status checked; it
does not perform a preliminary open/close probe. Physical KFF and Pi1541
validation remains an adapter-backed integration test, not a VICE PASS.

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
directory-state range, ordinary RUN after deliberately consuming the raw
trailer
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
