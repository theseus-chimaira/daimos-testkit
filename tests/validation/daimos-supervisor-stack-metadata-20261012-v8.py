#!/usr/bin/env python3
"""Check DXR2/ST2 stack metadata acceptance and rejection boundaries.

Run: DXRCHECK=/path/to/dxrcheck python3 this-file.py supervisor.dxr
The original executable is read only; every malformed trial is temporary.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


def word(data, offset):
    return int.from_bytes(data[offset : offset + 8], "little")


def replace_word(data, offset, value):
    result = bytearray(data)
    result[offset : offset + 8] = value.to_bytes(8, "little")
    return result


def check(checker, image, expected):
    with tempfile.TemporaryDirectory(prefix="daimos-dxr-st2-v8-", dir=os.environ.get("TMPDIR", os.path.expanduser("~/tmp"))) as tmp:
        filename = Path(tmp) / "test.dxr"
        filename.write_bytes(image)
        result = subprocess.run([checker, str(filename)], capture_output=True, text=True, check=False)
        if (result.returncode == 0) != expected:
            raise AssertionError(f"expected accepted={expected}, got return={result.returncode}: {result.stderr}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: daimos-supervisor-stack-metadata-20261012-v8.py supervisor.dxr")
    checker = os.environ.get("DXRCHECK", "dxrcheck")
    image = Path(sys.argv[1]).read_bytes()
    if len(image) < 24:
        raise AssertionError("DXR header truncated")
    header = word(image, 16)
    flags = word(image, 8)
    tag = header & 0o777777
    if tag != 0o636422 or (header >> 18) != 0o400:
        raise AssertionError("expected valid 0400-word ST2 supervisor")

    cases = [
        ("valid ST2 0400", image, True),
        ("stack below minimum", replace_word(image, 16, (0o377 << 18) | tag), False),
        ("stack above default", replace_word(image, 16, (0o2001 << 18) | tag), False),
        ("unknown extension tag", replace_word(image, 16, (0o400 << 18) | 0o123456), False),
        ("ST2 PURE forbidden", replace_word(image, 8, flags | 0o200000), False),
        ("ST2 compressed forbidden", replace_word(image, 8, flags | 0o100000), False),
    ]
    for name, contents, accepted in cases:
        check(checker, contents, accepted)
        print("PASS", name)


if __name__ == "__main__":
    main()
