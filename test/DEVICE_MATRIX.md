# SubDirCommander 4.0 device integration matrix

`sub40` means the current BASIC V2 and machine-language frontends. Every
device run must execute each applicable command for both frontends.

| Target | Virtual backend | Commands under test | Result without firmware adapter |
| --- | --- | --- | --- |
| Pi1541, D64 mode | VICE true-drive D64 | list, load, run, copy, move, delete, rename, validate, format | runnable |
| Pi1541, SD-card mode | Pi1541 firmware adapter | list, load, run, copy, move, delete, rename, MD, RD, CD:_, format | `SKIP` |
| SD2IEC | SD2IEC firmware adapter | list, load, run, copy, move, delete, rename, validate, format, MD, RD, CD:_ | `SKIP` |
| Kung Fu Flash / 2 | KFF firmware adapter | list, load, run, copy, move, delete | `SKIP` |

VICE's host-filesystem IEC backend is useful for a KERNAL file-system smoke
test, but it does not implement the SD2IEC DOS/folder contract. It must not
be reported as SD2IEC coverage.

## Required assertions

- PRG and NUL-containing SEQ copies are byte-exact.
- Duplicate, abort and full-media failures leave no partial output and retain
  the expected free blocks.
- Every supported command checks its DOS status; unsupported commands are
  reported as unavailable and leave the medium unchanged.
- Folder operations affect only the selected path.
- `:`, `,`, `=` and `"` never escape a typed or listed filename.

## Running

```bash
test/run_device_matrix.sh pi1541-d64
```

The Pi1541 D64 mode runs the existing true-drive VICE scenarios. The other
targets require a firmware/emulator adapter passed explicitly as one of
`SDC_SD2IEC_RUNNER`, `SDC_PI1541_SD_RUNNER` or `SDC_KFF_RUNNER`. The adapter
receives the device name and this matrix file; it must return nonzero on any
failed assertion. An unset adapter returns exit code 77 (`SKIP`), never PASS.
