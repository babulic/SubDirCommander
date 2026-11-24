# Codex review — SubDirCommander 3.9

> Status po optimalizácii BASICu: uzavreté a otvorené zistenia sú rozdelené
> v `CODE_REVIEW_CODEX_02.md`. Tento dokument zostáva zachovaný ako úplný
> historický audit a záznam rozhodnutí. Riadok o `mk% → m%` nižšie je
> nahradený korekciou: `dirread.asm` vyhľadáva `MK%` priamo v BASIC tabuľke,
> takže pole musí ostať pomenované `mk%`, kým sa helper nezmení.

Reviewed tree: local `main` after commits `4176934`, `cd7b0eb`, `01d6be7`,
and `f7c41a8`.  This is a separate review from `CODE_REVIEW.md` and includes
the test-suite audit.

## Product findings

### P1 — BASIC can overwrite its resident machine-code services

The BASIC frontend directly `LOAD`s and optionally `SYS`es a selected PRG at
line 4487/4489.  A returning PRG can overwrite services which the commander
will later call, while the UI continues as though it were intact.

| Resident service | Range | Later use |
| --- | --- | --- |
| Cross-drive copy helper | `$033C-$03C5` | `SYS 828` |
| Directory reader | `$C000-$C43F` | `SYS 49152` |
| DATA skipper | `$C500-$C5A9` | `SYS 50432` |
| Key panel renderer | `$C5B0-$C794` | `SYS 50608` |
| Hex-data decoder | `$C800-$C892` | `SYS 51200` |

This affects both `7` (run) and `8` (load): `8` does not execute the PRG but
still overwrites a resident routine.  Do not auto-repair it after the fact.
Before either command, calculate the conservative loaded range from the PRG
header plus its directory block count; if it intersects one or more rows in
the table, name the affected services and ask whether to continue.  Default
to cancel.  A confirmed operation intentionally leaves the commander altered.

### P1 — BAS and ML can try to execute RAM hidden by ROM or I/O

`$A000-$BFFF` is behind BASIC ROM, `$D000-$DFFF` maps I/O, and
`$E000-$FFFF` is behind KERNAL ROM in the normal `$01 = $37` map.  Both
frontends can currently load there with secondary address 1 and then execute
the visible ROM/I/O bytes instead of the loaded RAM.

- BASIC: `basic/SubDirCommand.39.txt`, line 4486 routes every start at or
  above `$A000` to the direct `LOAD ...,1` path.
- ML: `ml/sdc39.asm`, lines 906-908 jump to `direct` for every start at or
  above `$A000`, bypassing its later `$D000` range check.  `callml` restores
  `$01 = $37` at lines 1007-1018 before entering the PRG.

Validate the complete range before direct execution.  Visible direct-return
RAM is `$2300-$9FFF` or `$C000-$CFFF` for the ML version; banked and I/O
ranges need an explicit supported trampoline or a clear refusal.

### P2 — ML memory-map documentation is stale

`README.md` says the ML copy buffer begins at `$1D00`; the current assembled
label is `bufstart = $2300`.  The actual direct-load threshold in
`ml/sdc39.asm` compares against `#>bufstart`, so the documented behaviour at
`$1D00` is false.  Generate/document the map from labels and test the
boundaries `$22FF`, `$2300`, `$9FFF`, `$C000`, `$CFFF`, and `$D000`.

### P2 — DOS delimiters are passed through raw in names

Both frontends concatenate editable and directory-supplied names into DOS
commands.  `:`, `,`, `=`, and `"` can therefore become DOS syntax instead of
literal filename text for rename, copy, move, delete, format, and folder
actions.  Reject those characters in typed names and refuse destructive
actions for a listed name containing them unless a correct quoting strategy
is implemented.

## Test audit

### What now fails correctly

`test/runall.sh` is materially better after `4176934`: it has
`set -euo pipefail`, regenerates fixtures per scenario, and invokes Python
without `head`, `tail`, or `rg` pipelines.  A Python exception, timeout, or
fixture-build failure therefore fails the runner.

### What can still pass falsely

Most VICE scenarios remain diagnostic scripts: they print screen rows and
memory values rather than asserting expected values.  For example `t5.py`,
`m2.py`, `m4.py`, `m5.py`, `m6.py`, and `t11.py` can observe a wrong cursor,
DOS error, VARTAB value, or screen message and exit 0.

The prior runner also performed post-copy D64 comparisons; the current runner
does not.  Add explicit assertions for:

1. cursor/page position and highlighted entry after every navigation step;
2. expected DOS status for duplicate-name and full-disk copy failures;
3. byte-for-byte output for PRG and NUL-containing SEQ cross-drive copies;
4. no partial target entry and recovered free blocks after abort/full disk;
5. VARTAB/TXTTAB after BASIC load/run and restored key-repeat flag on exit;
6. warning-and-cancel/confirm paths for every resident-service overlap;
7. banked/I/O direct-address refusal and ML memory-map boundaries.

The artefact and fixture verification scripts do use real assertions and are
valuable release checks.  In this execution environment VICE itself cannot
create a display or remote monitor because no Xvfb server is installed; that
is an environment limitation, not a passing VICE result.

## BASIC optimization audit — before the resident-code redesign

This is a static audit of the current `basic/SubDirCommand.39.txt`, not an
implemented change set.  It separates removals that have no observable effect
from lifetime-based renames, which must be covered by a VICE regression run
when implemented.  `python3 test/verify_artifacts.py` passes for this
baseline.

The largest current tokenized BASIC record is line 5926 at 193 bytes,
including its link, line number and terminating zero.  Its sibling line 5925
is 187 bytes.  Keep a build-time measurement when changing these lines; do
not grow them while the current DATA loader exists.  The relevant practical
limit for a user-entered C64 BASIC line is not a safe limit to infer for a
tokenized PRG produced by `petcat`, so a measured release guard is preferable
to assuming a magic 255-byte value.

### Verified zero-effect removals and flow reductions

| Candidate | Current location | Verification | Safe replacement |
| --- | --- | --- | --- |
| `br$`, `lr$`, `rl$` | 5920 | Each is assigned once and never read. | Keep only `bf$=" blocks free.":goto5930`. |
| `nb=nb` | 1 | `nb` occurs only in this self-assignment. | Remove just this term from the force list. |
| `ma` | 4354, 5900 | Its only value is constant `500`: array dimensions and full-list guard. | `dim m$(500),mk%(500),kt%(255)` and `if m>=500 then return`; remove `ma=500`. |
| OS-detection entry | 4250, called only from 5016 | **Do not remove.** When `ST=0`, BASIC skips the same-line `RETURN` and falls into 4251–4259, which probes/initializes the drive OS. | Keep the entry and the `GOSUB 4250`. |
| Validate entry | 4260, called only from 2100 | **Do not remove.** When `ST=0`, it falls through 4263–4267 and sends Validate; when `ST<>0`, it prints and returns. | Keep the entry and the `GOSUB 4260`. |
| False-branch `GOTO` lines | 2605, 2705, 2955, 2975, 5165–5166 | **Do not merge.** In BASIC V2 a false `IF` skips the rest of its physical line, including text after `:`. | Keep the separate fall-through `GOTO` lines. |
| Drive-select padding | 5007 | The screen has just been cleared, so writing 15 white spaces has the same screen result as 15 cursor-right controls. | Use `;spc(15);` in place of the 15 `{rght}` controls. |

No other executable BASIC section is statically unreachable: every routine
from the command dispatcher through line 5950 has an incoming `GOTO`, `GOSUB`
or deliberate fall-through.  The later DATA records are reached by `READ`,
not by sequential execution, and are required by the current helper loader.

Do **not** remove the whole line-1 force list merely because it looks like
self-assignment.  Apart from `nb`, it creates the initial scalar-variable
layout before the program starts.  That changes BASIC's allocation behaviour
and available headroom; the machine-code helpers also inspect BASIC's
variable/array tables dynamically.  Removing the entire list needs an
emulator comparison, not a static claim.

### Verified single-character names

In BASIC V2, `d`, `d$` and `d%` are distinct variables.  A string or integer
array therefore does not collide with a numeric variable having the same
first letter.  The following direct mappings use otherwise free names and do
not rely on lifetime sharing.

| Current | Proposed | Role | Status |
| --- | --- | --- | --- |
| `dr` | `d` | current device | safe direct rename |
| `tp` | `t` | first entry of page | safe direct rename |
| `td` | `u` | target device | safe direct rename |
| `cn` | `n` | continuation/relist state | safe direct rename |
| `mc` | `k` | marked-file count | safe direct rename |
| `sp` | `e` | parser mode | safe direct rename |
| `ll` | `g` | list width | safe direct rename |
| `kb` | `a` | keyboard-buffer count | safe direct rename |
| `sk` | `h` | DATA-item skip count | safe direct rename |

These are the first direct-renaming phase.  Measure the resulting tokenized
PRG rather than using a textual count: BASIC keywords and variable names are
often intentionally adjacent (for example `ifdrthen`), so a regular-expression
count underestimates the exact byte saving.

| Current | Safer proposed reuse | Why it is safe only with a scoped audit |
| --- | --- | --- |
| `cv` | `i` | Every loop is outside a call that needs the old drawing index afterwards. |
| `kc` | `b` | `kc` cannot use `i`: line 4290 calls draw routine 33 and then routine 24 still needs the caller's `i`. `b` has no live value there. |
| `da`, `sa` | `c`, `x` | They are private temporaries of 32/33. All callers either reset `x` after drawing or do not need the parser cursor `c` afterwards. |
| `xi`, `pp` | `q`, `a` respectively | `xi → x` is **unsafe**: during the multi-copy loop, `GOSUB 4420` overwrites `x`, corrupting `FOR/NEXT`. `pp → a` may share `a` with `kb` because the keyboard-buffer path ends the program before any marked-file loop. |
| `e1`, `e2`, `e3` | `b`, `w`, `j` | These three DOS-status fields exist only inside 4252–4254; their previous values are dead on return. |
| `hd`, `ha`, `hb` | `h`, `c`, `f` | They are local to hex conversion 5950. The previous values are dead at each call site, but this should be changed only together with a regression of helper reload after cross-drive copy. |

The remaining two-letter numeric flags (`rd`, `ru`, `rl`, `ro`, `od`, `ft`,
`en`, `tr`, `se`) should stay named for now.  They span device I/O or the
direct-load handoff, so shortening them without a demonstrated non-overlapping
lifetime saves little and raises regression risk.

### Strings and integer arrays

| Current | Proposed | Status and caveat |
| --- | --- | --- |
| `os$` | `o$` | direct rename; numeric `o` is a different BASIC variable type |
| `bl$` | `w$` | direct rename |
| `bo$` | `v$` | direct rename; **not** `b$`, which is the loaded PRG high byte at 4220/4230 |
| `re$` | `r$` | direct rename |
| `ap$` | `g$` | direct rename; it is used at 4420, 4424 and twice at 4510, so replacing it repeatedly with `chr$(34)` grows the tokenized code rather than shrinking it |
| `bf$` | `u$` | direct rename |
| `er$` | `p$` | possible lifetime reuse: `p$` is only needed to reject a protected directory before every later DOS-status call. Test all delete and marked-delete paths. |
| `mk%` | unchanged | `dirread.asm` má PETSCII lookup pre `MK%`; bez zmeny helpera by sa pokazili značky súborov |
| `kt%` | `k%` | direct rename; distinct from numeric `k` |

The external suggestion that `ap$` occurs only twice is incomplete.  More
importantly, `chr$(34)` is longer than a one-character string variable at its
four uses.  Keep a variable, preferably `g$`.  Shortening visible copy such
as `"Waiting for device ..."` is optional UI wording change, not a
zero-impact optimization.  The duplicated `2950,2950` targets in the key
dispatch are intentional: two different keys invoke Format and must remain.

### Required checks when applying the optimization

1. Tokenize the changed listing and fail the build if any BASIC record exceeds
   the selected measured guard; report the longest line in the test output.
2. Re-run artifact verification and add assertions for the drive-select
   cursor position after replacing `{rght}` with `spc(15)`.
3. Exercise rename, single and marked delete, single and marked copy/move,
   directory create/remove, Format, and both direct `LOAD` paths.  These
   cover the lifetime-based aliases above.
4. Only after this cleanup, implement the separate trailer/bootstrap design
   for the resident helper routines described in the preceding discussion.

## Implementation result

Implemented in the current BASIC release:

- removed `nb`, `ma`, `br$`, `lr$` and `rl$`;
- applied the safe one-character aliases and the audited local reuse aliases;
- retained `mk%`, because `dirread.asm` performs a direct PETSCII lookup for
  `MK%`;
- replaced the drive-select cursor-right padding with `spc(15)`;
- added the tokenized BASIC-record guard to `test/verify_artifacts.py`.

The compiled BASIC PRG is now 13,662 bytes, down from 14,017 bytes (355 bytes
saved).  Artifact and deterministic-fixture verification pass.  The VICE
interaction suite still stops explicitly when this host cannot start its
remote monitor; it is not counted as a pass.
