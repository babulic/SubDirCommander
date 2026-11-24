# Codex review — SubDirCommander 3.9, follow-up 02

This is the authoritative list of findings still open after the BASIC
optimization recorded in `CODE_REVIEW_CODEX.md`.  It deliberately excludes
the completed identifier shortening, dead assignments and tokenized-line
length guard.

## P1 — Direct LOAD/RUN can overwrite the BASIC resident services

The BASIC frontend directly loads a selected PRG at 4487 and optionally
executes it at 4489.  A loaded PRG can overwrite one or more resident helpers
and then return to a Commander whose next directory, help-panel or copy call
uses corrupted code.

Current services are still at:

| Service | Current range | Use |
| --- | --- | --- |
| `COPY HELPER` | `$033C-$03C5` | cross-drive `SYS 828` |
| `DIR READ` | `$C000-$C43F` | `SYS 49152` |
| `DATA SKIP` | `$C500-$C5A9` | `SYS 50432` |
| `KEY PANEL` | `$C5B0-$C794` | `SYS 50608` |
| `HEX DECODE` | `$C800-$C892` | `SYS 51200` |

Before commands `7` (Run) and `8` (Load), calculate the conservative loaded
range from the PRG load address and directory block count.  If it intersects
any service, list the exact affected names and ask `y/n`:

- `7`: whether to run it anyway;
- `8`: whether to load it anyway.

Default is cancel.  A confirmed operation intentionally leaves Commander
memory altered; do not silently reinstall helpers afterwards.

### Approved follow-up architecture — not implemented yet

Replace the BASIC `DATA` helper payload with a binary trailer after the BASIC
program.  A startup bootstrap should reserve `$97F0-$9FFF`, set the BASIC
memory ceiling below it, then copy/execute helpers from these positions:

| Service | Planned range |
| --- | --- |
| `COPY HELPER` | `$97F0-$9879` |
| `DATA SKIP` | `$9880-$9929` |
| `KEY PANEL` | `$9930-$9B14` |
| `HEX DECODE` | `$9B20-$9BB2` |
| `DIR READ` | `$9BC0-$9FFF` |

The direct-load warning remains necessary after this move because KERNAL
`LOAD` does not respect BASIC's memory ceiling.

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
commands. BASIC reads typed names using a V2-compatible `GET` editor, so
`INPUT` cannot consume a delimiter before validation. ML checks both typed
and listed names. `t15.py` asserts that BASIC refuses typed `bad:name` and
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

## Remaining test debt

`test/runall.sh` correctly fails on shell/Python/fixture errors, and
`verify_artifacts.py` now also rejects a BASIC record longer than 200 bytes.
The asserted VICE coverage includes BASIC cursor/page movement (`t5.py`),
byte-exact cross-drive PRG copy plus duplicate protection (`t6.py`), typed
DOS-delimiter rejection (`t15.py`), and ML address/name boundaries (`m8.py`).
Other scenarios still only print screen/memory observations and can return
success after a wrong result.

Still add asserted VICE coverage for:

1. ML cursor/page/highlight state after navigation;
2. full-disk/abort cleanup: no partial target and recovered free blocks;
3. NUL-containing SEQ cross-drive copy;
4. BASIC `VARTAB`/`TXTTAB` after Load/Run and restored key-repeat on exit;
5. cancel/confirm for every resident-service overlap on both `7` and `8`;
6. helper reload after cross-drive copy, including preserved `MK%` marks.

VICE tests run in VICE console mode when executed outside the filesystem
sandbox, which must be allowed to create the loopback remote-monitor socket.
The normal sandbox cannot open that socket; a socket failure is not a pass.
Each VICE scenario now chooses its own loopback monitor port, so an interrupted
scenario cannot silently drive a stale emulator from a previous run.
