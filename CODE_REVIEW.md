# SubDirCommander 3.9 review

Scope: the BASIC V2 release in `basic/SubDirCommand.39.txt` and the 6502
release in `ml/sdc39.asm`, as currently present in this project directory.

## Findings

### P1 — BAS and ML execute load addresses hidden by ROM or I/O

Both variants can take the in-application load-and-`SYS` path for a PRG whose
start is `$A000-$BFFF`, `$D000-$DFFF`, or `$E000-$FFFF`.  With the normal
`$01 = $37` memory map, those ranges read BASIC ROM, I/O registers, or KERNAL
ROM rather than the bytes just loaded into RAM.  `SYS` therefore runs the
wrong code (or hits I/O), despite the UI reporting a successful load.

- BASIC: [`basic/SubDirCommand.39.txt`](basic/SubDirCommand.39.txt) line 4486
  sends every start address at or above decimal 40960 (`$A000`) to line 4487,
  which does `LOAD ...,1`; line 4489 then does `SYS s` without banking ROM/I/O
  out.
- ML: [`ml/sdc39.asm`](ml/sdc39.asm) lines 906-908 jump directly to `direct`
  for every address at or above `$A000`, bypassing the later `$D000` end-range
  guard.  `callml` explicitly restores `$01` to `$37` at lines 1007-1018
  before the indirect `RTS` into the loaded program.

Reproduction fixture to add for each frontend: a one-block PRG starting at
`$A000` that writes a marker to screen RAM.  `7` should either execute it
under an explicit RAM banking contract, or reject/hand it off with a clear
unsupported-address message; it must not claim success and execute ROM.

Recommended fix: define one shared executable direct-load interval, validate
the *whole loaded range*, and allow direct return only in visible RAM (for
example `$2300-$CFFF` for the current ML layout).  For ROM/I/O ranges, reject
them unless a small, documented banking trampoline safely enters and restores
the target program.

### P2 — ML memory-map documentation no longer matches the assembled binary

The README says code ends at `$1B1A` and the copy buffer begins at `$1D00`
([`README.md`](README.md) lines 131-139).  The current assembly's generated
label is `bufstart = $2300` (from `64tass -l`), and the direct-load decision
uses `#>bufstart` at [`ml/sdc39.asm`](ml/sdc39.asm) lines 932-940.  A program
at `$1D00`, documented as returning to the commander, is now handed off to
BASIC instead.

Update the memory map and the return contract in the README, and add boundary
tests at `$22FF`, `$2300`, `$CFFF`, and `$D000`.

### P2 — DOS command delimiters are accepted in names and concatenated raw

The name prompts accept DOS separators such as `:`, `,`, and `=` and both
frontends append them directly into command strings.  For example, BASIC
constructs `r:`/`c:` commands at lines 4279 and 4351, and the ML version
builds the same unescaped command buffer at
[`ml/sdc39.asm`](ml/sdc39.asm) lines 366-372 and 1853-1874.  A typed or
listed filename containing a delimiter can be parsed as drive syntax rather
than a literal name, so rename, copy, move, delete, format, and directory
commands may target something other than the displayed entry.

Reject DOS command delimiters in editable names (and detect them in listed
names before a destructive action), or add a correct drive-specific quoting
layer.  Cover `:`, `,`, `=`, and a quote in both BAS and ML prompt tests.
