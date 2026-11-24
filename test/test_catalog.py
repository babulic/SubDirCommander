"""Human-readable names and purposes for official SubDirCommander tests."""

from __future__ import annotations


# id: (report title, purpose, filename slug)
SCENARIOS: dict[str, tuple[str, str, str]] = {
    "t4": ("BASIC navigation smoke test", "Shows the initial directory and exercises page and cursor movement.", "basic-navigation-smoke"),
    "t5": ("BASIC cursor and page assertions", "Asserts the highlighted row and selected entry across page changes and wraps.", "basic-cursor-page-assertions"),
    "t6": ("BASIC cross-drive copy integrity", "Checks byte-exact PRG copy, free-block delta and duplicate-file status 63.", "basic-cross-drive-copy-integrity"),
    "t7": ("BASIC large copy and disk-full handling", "Copies Oxford Pascal, then exercises SEQ copy into a full target disk.", "basic-large-copy-disk-full"),
    "t8": ("BASIC Load and subsequent SAVE", "Loads a BASIC program, inspects BASIC pointers, then saves and lists it.", "basic-load-save"),
    "t9": ("BASIC Run/Load machine-code paths", "Runs $C000 ML, copies a SEQ file and hands $1000 ML back to BASIC.", "basic-run-load-ml"),
    "t10": ("BASIC ML handoff memory state", "Runs overlapping $1000 ML and observes BASIC pointers and key-repeat state.", "basic-ml-handoff-memory"),
    "t11": ("BASIC command workflow", "Exercises validate, rename, start-address display, delete and exit.", "basic-command-workflow"),
    "t12": ("BASIC disk-full copy result", "Copies a selected file to the full target and observes DOS disk-full status.", "basic-disk-full-copy"),
    "t13": ("BASIC direct Load at $C000", "Loads a $C000 program without running it and observes the selected entry.", "basic-direct-load-c000"),
    "t14": ("BASIC and ML start-address display", "Checks start-address display and cross-drive SEQ copy in both frontends.", "basic-ml-start-address"),
    "t15": ("BASIC INPUT unsafe DOS-name rejection", "Proves quoted `bad:name` is rejected without changing the source file.", "basic-input-unsafe-dos-name-rejection"),
    "t16": ("BASIC marked-file cross-drive copy", "Marks FILE05 with Space and verifies that Copy transfers that marked file byte-exactly.", "basic-marked-file-cross-drive-copy"),
    "m1": ("ML navigation smoke test", "Shows the ML frontend and exercises basic cursor and page movement.", "ml-navigation-smoke"),
    "m2": ("ML navigation and command workflow", "Exercises page/wrap navigation, start address, rename, delete and validate.", "ml-navigation-command-workflow"),
    "m4": ("ML disk-full and duplicate copy handling", "Exercises cross-drive copy failures on a full target and duplicate outcomes.", "ml-disk-full-duplicate-copy"),
    "m5": ("ML cross-drive copy, Run and Load", "Copies Oxford Pascal, runs $C000 ML and performs Load-only behavior.", "ml-copy-run-load"),
    "m6": ("ML BASIC/ML handoff and exit", "Covers BASIC Load/Run, overlapping ML handoff, exit and rerun behavior.", "ml-handoff-exit-rerun"),
    "m7": ("External commander launch", "Launches the dc64 program from both ML and BASIC frontends.", "external-dc64-launch"),
    "m8": ("ML memory boundaries and unsafe listed names", "Checks supported ML boundaries, probes $D000 and rejects raw BAD:NAME deletion.", "ml-boundaries-unsafe-name"),
}

FULL_SUITE = (
    "t4", "t5", "t6", "t7", "t8", "t9", "t10", "t11", "t12", "t13", "t14", "t15", "t16",
    "m1", "m2", "m4", "m5", "m6", "m7", "m8",
)

DEVICE_TARGETS: dict[str, tuple[str, str, str]] = {
    "pi1541-d64": ("Pi1541-compatible D64 matrix", "Runs the true-drive VICE D64 subset used for Pi1541 disk-image compatibility.", "pi1541-d64"),
    "pi1541-sd": ("Pi1541 SD-card browser matrix", "Requires a Pi1541 browser-mode firmware/emulator adapter.", "pi1541-sd-card-browser"),
    "sd2iec": ("SD2IEC firmware matrix", "Requires an SD2IEC firmware/emulator adapter for IEC folder/DOS behavior.", "sd2iec-firmware"),
    "kungfuflash": ("Kung Fu Flash device matrix", "Requires a Kung Fu Flash firmware/emulator adapter.", "kung-fu-flash"),
}
