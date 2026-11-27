#!/usr/bin/env python3
"""Keep documented device claims synchronized with the executable matrix."""

from __future__ import annotations

import re
from pathlib import Path

from device_matrix import MATRIX


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    web = re.sub(r"\s+", " ", (ROOT / "web" / "index.html").read_text(encoding="utf-8"))
    assert set(MATRIX) == {"sd2iec", "pi1541-d64", "pi1541-sd", "kungfuflash"}
    for device, spec in MATRIX.items():
        assert spec["commands"], device
        assert spec["assertions"], device
    for text in (readme, web):
        assert "SD2IEC" in text
        assert "pi1541" in text
        assert "Kung Fu Flash" in text
    assert readme.lower().count("make or remove a folder") == 3
    assert "delete, validate and format" in readme.lower()
    assert "cached status title" in readme.lower()
    assert "fat 8.3 alias" in readme.lower()
    assert "fat 8.3 alias" in web.lower()
    assertions = " ".join(
        assertion for spec in MATRIX.values() for assertion in spec["assertions"]
    ).lower()
    assert assertions.count("refreshes the actual") == 3
    print("PASS: SubDirCommander 4.0 device matrix agrees with README and web claims")


if __name__ == "__main__":
    main()
