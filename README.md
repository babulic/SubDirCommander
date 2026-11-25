# SubDirCommander 2026 for the Commodore 64

https://subdir-commander.apps.grok.bot/

A file manager for COMMODORE 64.
List a drive, move through it a line or a page at a time, and run, load, copy,
move or delete files, including copies from one drive to another. Rename,
validate and format depend on the drive.

Utilizes 1541 / 1541-II, SD2IEC, pi1541 or Kung Fu Flash on a Commodore C64.

It comes in two versions with the same screen and keys.

- Commodore 1541 does the whole set, including rename, validate and format.
- SD2IEC does that too, and it makes, removes and leaves directories.
- pi1541 does the same inside a disk image. On the SD card it renames, copies,
  deletes and creates folders; validate is not implemented, and format creates
  a new D64 ([IEC commands](https://github.com/pi1541/Pi1541/blob/master/docs/IEC%20Commands.md)).
- Kung Fu Flash and Kung Fu Flash 2 list, load, run, delete, copy and move.
  Rename, validate and format are not in that firmware
  ([Kung Fu Flash 2](https://github.com/KimJorgensen/KungFuFlash2)).

| File | Kind | Size |
| --- | --- | --- |
| `dist/SubDirCommand.40.prg` | BASIC V2 | 41 blocks |
| `dist/%SubDirCommand.40.prg` | 6502 machine code, `SYS2061` stub | 26 blocks |
| `dist/SubDirCommand.40.d64` | slim 1541 disk with both programs | |
| `dist/fb.d64` | frequently-used disk with both programs | |

`%` is an ordinary character in a 1541 file name.

## Run it

In VICE on the Mac:

```bash
x64sc -8 dist/fb.d64
```

Then on the C64, in lowercase:

```text
load "SubDirCommand.40",8
run
```

```text
load "%SubDirCommand40",8
run
```

A copy from one drive to another needs a second disk. In VICE on the computer, attach it as drive 9. That flag belongs on the `x64sc` command, not on the C64:

```bash
x64sc -8 dist/fb.d64 -9 other.d64
```

`other.d64` is any second disk image. On a real C64, use the two drives you have and pick the target drive in the commander.

## Keys

| Key | Action |
| --- | --- |
| CRSR up / down | one line |
| CRSR left / right | page up / page down (22 lines; on the first or last page: first or last entry) |
| 1 / F1 | choose the drive and list it |
| 2 / F2 | validate the disk and list again |
| 3 / F3 | rename |
| 4 / F4 | copy: name (RETURN = same name), then target drive (default: current) |
| 5 / F5 | show the start address of a PRG |
| 6 / F6 | delete (asks y/n; not locked files) |
| 7 / F7 / RETURN | run a program, enter a directory or disk image, run an `&` USR file in the drive |
| 8 / F8 | load a program without running it (directories and images open like 7) |
| 9 | move a file, on this drive or to another |
| 0 | format the disk |
| N / R | SD2IEC and pi1541: make or remove a directory |
| Space / * | mark one file, or mark and clear all |
| ↑ | SD2IEC and pi1541: one directory level up (`CD:←`) |
| ← | quit to BASIC |

The key panel on the right says `U/D Move CRSR` and `L/R Page UpDn`.
Validate, rename and format need a 1541, an SD2IEC, or a pi1541 disk image.
On Kung Fu Flash, use list, load, run, copy, move and delete.

Copy to another drive streams the file through the C64. PRG, SEQ and USR
files can be copied; REL files cannot. A failed copy (disk full, write
error, RUN/STOP) removes the partial file and validates the target so its
blocks come back. Copy on the same drive still uses the drive's own `C:`.

## What changed in `.40`

- BASIC helpers are no longer stored as `DATA` fields. A binary trailer after
  the BASIC terminator copies them at startup into `$97F0-$9FFF`. The first
  line first detects the return from an in-program `LOAD`; otherwise it
  reserves that RAM, runs `CLR`, sets `VARTAB` to the trailer, runs `CLR`
  again, and only then `SYS`es the relocator.
- The tokenized BASIC program ends at `$2916`; the binary trailer begins at
  `$2917`. The trailer is only a transport: it is copied from the file image
  first, then BASIC allocates its variables below `$97F0`. The live services
  are `COPY HELPER` `$97F0-$9879`, `DIR HEADER/WORK` `$9880-$98F2`, `KEY
  PANEL` `$9930-$9B14` and `DIR READ` `$9B20-$9F6F`. No unused loader or
  hex-decoder routine is distributed.
- Before `7` / `8`, BASIC checks the complete resident interval
  `$97F0-$9F6F` and displays `Program will hit Commander's routines!` before
  it asks whether a PRG may overwrite it. A PRG at `$0801` is handed straight
  to BASIC without that dialog, because it replaces the Commander. KERNAL
  `LOAD` can still write above BASIC's memory ceiling, so the confirmation
  remains necessary for the direct-return path.
- `$C000-$CFFF` no longer contains any BASIC Commander code or state: a PRG
  loaded at `$C800` or `$C900` is not damaged by Commander state, nor can it
  corrupt it merely by being loaded. The only other temporary high-RAM use is
  the cross-drive Copy buffer at `$A000-$BFFF`, behind BASIC ROM, and it is
  used only while that Copy is running.

Current command behavior:

- CRSR right no longer moves up a line. CRSR left/right now page.
- Copy asks for the target drive.
- **SAVE after loading a program saved the size of the commander.** `.37`
  ran `LOAD` inside the running program. BASIC treats that as chaining: it
  starts the new program but keeps the old end-of-program pointer
  (`VARTAB`, `$2D/$2E`), so `SAVE` wrote 22 blocks even for a 2-block
  program, and a program longer than the commander had its variables placed
  inside its own code. The current release hands the program to BASIC the way you would
  type it: it prints `LOAD"name",8` then queues `RUN` for BASIC, or
  `LOAD"name",8,1` then queues `SYS address` for machine code, and ends.
  BASIC then sets
  `VARTAB` itself. Before that it empties the BASIC program (zero link at
  `$0801`), because BASIC re-links the old program text after a direct
  `LOAD` and would otherwise overwrite machine code loaded into that area.
  Machine code that loads clear of the commander (for example at `$C000`)
  still loads from inside the program and returns afterwards.
- `8` (load) no longer starts BASIC programs; with chaining it always did.

## Review of `SubDirCommand.37`

The program is 169 lines (3000-5260). Line 3000 catches the restart after a
machine code `LOAD`; 3300-3820 are helpers (delay, screen frame, list
redraw, read-only check, wait for device); 4000-4160 read the drive status;
4200-4496 are the commands; 5000-5260 are set-up, directory reading and the
key loop. The directory is held in `M$()`/`S()` (up to 257 entries) and
shown in fixed pages of 22 entries.

Defects found in `.37` and fixed:

1. CRSR right moved the cursor up (line 5181).
2. `LOAD` in program mode kept the old `VARTAB` (see above). The `.37` file
   itself was saved that way: it carries 277 bytes of garbage after the end
   of the program.
3. `O%=-1` in line 5190 sets an integer variable no other line reads; `O`
   was meant, so after Validate the drive prompt came back.
4. Key repeat (`POKE650,128`) stayed on after quitting.
5. "Ran OK, press any key" left one letter of the line underneath.
6. "Load & run as Basic program from $2049" mixed hex notation and a decimal
   value; "Load from $" printed no address.
7. Copy on a full list could index past `M$(256)`.
8. The blocks-free line was shown as `27blocks free.` (no space).

Notes, not changed in the BASIC version: line 5110 assumes every directory
line is 32 bytes (true for 1541 and SD2IEC); typing over a two-digit default
in the drive prompt leaves the second digit; `UI` resets the drive on every
listing.

## Machine language version

`ml/sdc40.asm` (64tass). Same screen, keys and behaviour; the list is drawn
straight into screen RAM, so moving and paging are instant.

- Code `$0801-$1B1A`, work variables up to `$1C86`.
- Directory: RAM under the BASIC ROM, `$A000-$BFFF`, 32 bytes per entry,
  up to 242 entries.
- Copy buffer: `$2300-$9FFF` (31.25 KiB), so most files copy in one pass.
- Zero page `$4B-$72` holds the hot variables; BASIC's own bytes there
  (including its `JMP` at `$54`) are saved at start and put back on exit and
  while a loaded program runs.
- The copy buffer begins at the assembled `bufstart` label, `$2300`.
  The ML direct-return contract is only `$2300-$9FFF` or `$C000-$CFFF`.
  `$A000-$BFFF` (BASIC ROM), `$D000-$DFFF` (I/O) and `$E000-$FFFF`
  (KERNAL ROM) are not direct-return targets; unsupported addresses must be
  handed to BASIC rather than executed inside the commander.
- The line editor in the prompts: first key replaces the default, DEL
  deletes, RETURN accepts, RUN/STOP cancels. RUN/STOP in the drive prompt
  quits.

## Build and test

```bash
python3 tools/build40.py # petcat, 64tass and c1541 -> dist/
```

`basic/SubDirCommand.40.txt` is the petcat listing of the BASIC program;
`basic/trailer40.asm` is the binary transport appended after its terminator.
The common helper sources are assembled at the 4.0 resident addresses by
`tools/build40.py`. `original/` holds the extracted `.37` and the untouched
`fb.d64`.

`test/` drives VICE through its remote monitor. The 4.0 runner exercises the
BASIC bootstrap and relocation, cross-drive Copy/Move, the direct Load/Run
handoff paths and the exact resident-overlap warning. Device commands that
need firmware semantics run through explicit adapters.

Use the official runners for a persistent latest result:

```bash
test/run40.sh                   # 4.0 trailer, relocation, Copy and warning regression
test/run_device_matrix.sh sd2iec
```

`test/run40.sh` rewrites `TEST_REPORT_SUB40.md` on every exit and keeps one
timestamped 4.0 report under `test/reports/`. A failed run writes `FAIL`, so
it cannot leave a stale PASS behind.
