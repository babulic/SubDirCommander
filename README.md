# SubDirCommander 2026 for the Commodore 64

https://subdir-commander.apps.grok.bot/

**A file manager for COMMODORE 64.** List a drive, move through a list of files
and folders a line or a page at a time, load and run files, rename and delete
files, copy and move files including copies from one drive to another, format a
CBM disk and create a new D64 disk image on SD2IEC/pi1541/KFF, validate a CBM
disk.

Commodore 64 · 1541 / 1541-II · SD2IEC · pi1541 · Kung Fu Flash. Two versions
with the same screen and keys.

## Support

Please support the project with a small contribution, as it consumes a
significant amount of time and AI tokens. Thanks you very much ! ♥

- [Pay by card (SumUp · card, Apple Pay, Google Pay)](https://pay.sumup.com/b2c/Q2TQPIJA)
- [Donate with PayPal](https://www.paypal.com/donate/?business=ivan.babulic%40gmail.com&currency_code=EUR)
- [PayPal.me](https://paypal.me/IvanBabulic)

## Drives

| Drive | What it can do |
| --- | --- |
| 1541 / 1541-II | The whole set: rename, copy, move, delete, validate and format. |
| SD2IEC | Navigate through folders; make or remove a folder. File operations: rename, copy, move, delete. Format creates a new D64 image. [SD2IEC](https://github.com/thierer/sd2iec). |
| pi1541 | Navigate through folders; make or remove a folder. File operations: rename, copy, move, delete. Format creates a new D64 image. Names in folders are cut to 16 characters. [Command list](https://github.com/pi1541/Pi1541/blob/master/docs/IEC%20Commands.md). |
| Kung Fu Flash | Navigate through folders; make or remove a folder. File operations: rename, copy, move, delete. Format creates a new D64 image. [Kung Fu Flash 2](https://github.com/KimJorgensen/KungFuFlash2). |

SD2IEC and Kung Fu Flash return a long host-file name as a FAT 8.3 alias such
as `NAME56~1.D64`.

| File | Kind | Size |
| --- | --- | --- |
| `dist/SubDirCommand.40.prg` | BASIC V2 | 46 blocks |
| `dist/%SubDirCommand.40.prg` | 6502 machine code, `SYS2061` stub | 29 blocks |
| `dist/SubDirCommand.40.d64` | slim 1541 disk with both programs | |
| `dist/fb.d64` | frequently-used disk with both programs | |

`%` is an ordinary character in a 1541 file name.

## Run it

As VICE emulation:

```bash
x64sc -8 dist/SubDirCommand.40.d64 -9 dist/fb.d64
```

On C64 run:

```text
load "%SubDirCommand40",8
run
```

for the machine code version, or

```text
load "SubDirCommand.40",8
run
```

for the BASIC one. On a real C64, use the two drives you have and pick the
target drive in the commander.

## Keys

| Key | Action |
| --- | --- |
| CRSR up / down | one line |
| CRSR left / right | page up / page down (22 lines) |
| 1 · F1 | choose the drive and list it |
| 2 · F2 | validate the disk |
| 3 · F3 | rename a file, disk image or root-level folder |
| 4 · F4 | copy: new name, then target drive (default: the current one) |
| 5 · F5 | start address of a program |
| 6 · F6 | delete an item, after y/n |
| 7 · F7 · RETURN | run a program, open a directory or disk image |
| 8 · F8 | load a program without running it |
| 9 | move a file, on this drive or to another |
| 0 | new/form disk |
| N | SD2IEC and pi1541: make a directory |
| Space / * | mark one file, or mark and clear all |
| ↑ | SD2IEC and pi1541: one directory level up |
| ← | quit to BASIC |

## Two versions

**Machine code** draws the directory list straight into screen memory, so
scrolling and paging are instant. It keeps the directory in the RAM under the
BASIC ROM. Copying between drives uses a 30.5 KiB buffer at `$2600-$9fff`.

After Load or Run, you get the file list back only if the program loaded into
`$2600-$9fff` or `$c000-$cfff`. Something that loads lower — for example at
336 (`$0150`), in unused RAM at `$02a7-$02ff`, or in the cassette buffer at
828 (`$033c`) — still runs via `LOAD"name",8,1` then `SYS`, but the commander
does not reopen the list afterward. Same for ROM and I/O addresses.

**BASIC** ends at `$2db1`; its transport trailer starts at `$2db2`, then
relocates the services to `COPY $97f0-$9879`, `HEADER/WORK $9880-$98f2`,
`PANEL $9930-$9b14` and `DIR READ $9b20-$9f6f`.

## Loading

When the commander cannot keep control, it prints the load the way you would
type it: `LOAD"name",8` then `RUN` for a BASIC program, or `LOAD"name",8,1`
then `SYS` for machine code. Then it exits. BASIC then owns the loaded
program, so a later BASIC `SAVE` writes that program’s real size — not the
size of the commander.

## Copying

A failed copy between drives (disk full, write error, RUN/STOP) deletes the
partial file and frees its blocks via the `VALIDATE` command. On
`FILE EXISTS`, the commander asks before replacing that one target; another
key skips it. Plain C64 files copy anywhere; a folder or disk image taken from
an SD2IEC/pi1541/KFF root needs another root as its cross-device target, never
an opened disk image.

Copy to another drive streams the file through the C64. PRG, SEQ and USR
files (including an image listed as PRG) can be copied; REL files cannot. A
Move scratches its source only after the copy or replacement succeeded. Copy
on the same drive still uses the drive's own `C:`.

The virtual-root distinction is DOS based, not a firmware-version guess:
`CBM`, `COP` and `JIF` OS headers mean an open disk or image; every other
header is a device root.

At a root, a name extension decides what `5`, `7` and `8` do. A mountable
image opens with `CD:` like a folder: SD2IEC mounts `.D64`, `.D41`, `.D71`,
`.D81`, `.DNP` (and the deprecated `.M2I`), pi1541 also `.G64` and `.T64`.
`.PRG` is a normal program. Any other extension (`.CRT`, `.SID` ...) is a host
file and is reported as `Not a C64 program !` instead of being loaded. Inside
an opened disk, a dot in a name has no meaning.

Entering an image and returning with `CD:` + left-arrow always invalidates the
cached status title before the next listing, so the title is read again from
the current device. This is deliberately a refresh, not a firmware-name
guess: SD2IEC, pi1541 and Kung Fu Flash supply their own status text.

## What changed in `.40`

- BASIC helpers are no longer stored as `DATA` fields. A binary trailer after
  the BASIC terminator copies them at startup into `$97F0-$9FFF`. The first
  line first detects the return from an in-program `LOAD`; otherwise it
  reserves that RAM, runs `CLR`, sets `VARTAB` to the trailer, runs `CLR`
  again, then checks a two-byte signature of the relocated COPY HELPER.
  A fresh launch calls the relocator; a normal `RUN` after `RUN/STOP` uses the
  already-resident helpers and never executes the consumed transport.
- The tokenized BASIC program ends at `$2DB1`; the binary trailer begins at
  `$2DB2`. The trailer is only a transport: it is copied from the file image
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

- Code `$0801-$23F9`, with `bufstart` aligned after it.
- Directory: RAM under the BASIC ROM, `$A000-$BFFF`, 32 bytes per entry,
  up to 242 entries.
- Copy buffer: `$2600-$9FFF` (30.5 KiB), so most files copy in one pass.
- Zero page `$4B-$72` holds the hot variables; BASIC's own bytes there
  (including its `JMP` at `$54`) are saved at start and put back on exit and
  while a loaded program runs.
- The copy buffer begins at the assembled `bufstart` label, `$2600`.
  The ML direct-return contract is only `$2600-$9FFF` or `$C000-$CFFF`.
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
