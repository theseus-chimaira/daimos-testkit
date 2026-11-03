#!/usr/bin/env python3
"""Verify DXR2 ST2 stack metadata handling using small host fixtures."""

import pathlib
import struct
import subprocess
import sys


def main():
    checker = sys.argv[1]
    directory = pathlib.Path(sys.argv[2])
    magic = (0o44 << 12) | (0o70 << 6) | 0o62
    cases = (
        ("st2-minimum", 0o400, 0o636422, 0, True),
        ("st2-maximum", 0o2000, 0o636422, 0, True),
        ("st2-below-minimum", 0o377, 0o636422, 0, False),
        ("st2-above-maximum", 0o2001, 0o636422, 0, False),
        ("st2-pure-flag", 0o400, 0o636422, 0o200000, False),
        ("tx2-valid", 1, 0o647022, 0, True),
        ("tx2-text-overflow", 2, 0o647022, 0, False),
    )
    for name, value, tag, flags, accepted in cases:
        path = directory / (name + "-v1070.dxr")
        words = [magic << 18, (1 << 18) | flags,
                 (value << 18) | tag, 0, 0]
        path.write_bytes(b"".join(struct.pack("<Q", w) for w in words))
        result = subprocess.run([checker, "-q", str(path)],
                                capture_output=True, text=True, check=False)
        if (result.returncode == 0) != accepted:
            sys.stderr.write("FAIL: " + name + "\n" + result.stderr)
            return 1
        print("PASS: " + name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
