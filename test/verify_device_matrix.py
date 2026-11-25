#!/usr/bin/env python3
"""Keep documented device claims synchronized with the executable matrix."""

from __future__ import annotations

from pathlib import Path

from device_matrix import MATRIX


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    web = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
    assert set(MATRIX) == {"sd2iec", "pi1541-d64", "pi1541-sd", "kungfuflash"}
    for device, spec in MATRIX.items():
        assert spec["commands"], device
        assert spec["assertions"], device
    for text in (readme, web):
        assert "SD2IEC" in text
        assert "pi1541" in text
        assert "Kung Fu Flash" in text
    assert "rename, validate and format are not" in readme.lower()
    assert "validate is not implemented" in readme.lower()
    print("PASS: SubDirCommander 4.0 device matrix agrees with README and web claims")


if __name__ == "__main__":
    main()
