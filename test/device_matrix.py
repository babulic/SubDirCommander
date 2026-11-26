"""Capability contract for SubDirCommander 4.0 (`sub40`) device suites.

The matrix is intentionally data, not an optimistic compatibility claim.
An adapter must report every listed command as pass, fail or skip; a missing
firmware backend is a skip and cannot become a green device result.
"""

from __future__ import annotations


MATRIX = {
    "sd2iec": {
        "virtual_backend": "firmware adapter (VICE filesystem is not equivalent)",
        "commands": (
            "list", "load", "run", "copy", "move", "delete", "rename",
            "validate", "format", "mkdir", "rmdir", "parent",
            "root-files",
        ),
        "assertions": (
            "PRG and NUL-containing SEQ copy are byte exact",
            "duplicate and full-media copy leave no partial target",
            "root folder/image Copy/Move rejects an opened-disk target; plain C64 files may go there",
            "7/8 at the root mount D64/D41/D71/D81/DNP/M2I and refuse non-PRG host extensions",
            "duplicate target asks once; decline skips only that item",
            "MD, RD and CD:_ change only the requested directory",
            "CD:_ after an image refreshes the actual SD2IEC firmware title",
            "a firmware-supplied FAT 8.3 alias is displayed and used byte for byte",
            "rename/delete never interpret : , = or quote in a filename",
        ),
    },
    "pi1541-d64": {
        "virtual_backend": "VICE true-drive D64 (1541 protocol compatibility)",
        "commands": ("list", "load", "run", "copy", "move", "delete", "rename", "validate", "format"),
        "assertions": (
            "PRG and NUL-containing SEQ copy are byte exact",
            "duplicate and full-disk failure recover target free blocks",
            "rename, delete, validate and format return a checked DOS status",
        ),
    },
    "pi1541-sd": {
        "virtual_backend": "Pi1541 SD-card firmware adapter",
        "commands": ("list", "load", "run", "copy", "move", "delete", "rename", "mkdir", "rmdir", "parent", "format", "root-files"),
        "assertions": (
            "folder commands follow Pi1541 IEC semantics",
            "validate is reported unsupported rather than treated as success",
            "format creates the requested D64 without changing siblings",
            "blank root Disk ID sends ,00; blank mounted-image ID remains quick format",
            "root-file image Copy/Move requires another root target; a plain PRG does not",
            "CD:_ after an image refreshes the actual Pi1541 firmware title",
        ),
    },
    "kungfuflash": {
        "virtual_backend": "Kung Fu Flash firmware adapter",
        "commands": ("list", "load", "run", "copy", "move", "delete", "rename", "root-files"),
        "assertions": (
            "root-file image/PRG Rename/Delete/Copy/Move preserve bytes and DOS status",
            "7/8 on a CRT or other non-PRG extension reports Not a C64 program and does not load it",
            "folder commands report unavailable and do not mutate media",
            "CD:_ after an image refreshes the actual KFF firmware title",
            "a firmware-supplied FAT 8.3 alias is displayed and used byte for byte",
        ),
    },
}
