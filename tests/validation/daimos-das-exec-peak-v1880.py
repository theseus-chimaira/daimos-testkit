#!/usr/bin/env python3
"""Enforce DAS's steady-state 16K-word EXEC-chain memory contract.

The native driver replaces itself with DAS1, which replaces itself with
DAS2.  Thus the peak *steady-state user process allocation* is the
maximum, not the sum, of the three reserved image+BSS+stack budgets.
This test does not certify transient kernel VM staging during EXEC.
"""

import argparse
import pathlib


MAX_WORDS = 0o40000
STACK_WORDS = 0o2000
MAGIC = 0o447062
BSS_MASK = 0o77777


def image_sizes(path):
    with path.open("rb") as stream:
        header = stream.read(16)
    if len(header) != 16:
        raise ValueError("incomplete native image: %s" % path)
    h0 = int.from_bytes(header[0:8], "little")
    h1 = int.from_bytes(header[8:16], "little")
    if h0 >> 18 != MAGIC:
        raise ValueError("not a DXR image: %s" % path)
    return (h1 >> 18) & 0o777777, h1 & BSS_MASK


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", required=True, type=pathlib.Path)
    args = parser.parse_args()
    maximum = 0
    for image in ("das", "das1", "das2"):
        code, bss = image_sizes(args.build_dir / (image + ".dxr"))
        resident = code + bss + STACK_WORDS
        maximum = max(maximum, resident)
        print("%s image=%06o bss=%06o stack=%06o resident=%06o" %
              (image, code, bss, STACK_WORDS, resident))
        if resident >= MAX_WORDS:
            raise SystemExit("FAIL: %s requires %06o words; limit %06o" %
                             (image, resident, MAX_WORDS))
    print("PASS: EXEC-chain steady-state peak %06o < %06o octal words; "
          "remaining %06o" % (maximum, MAX_WORDS, MAX_WORDS - maximum))
    print("NOTE: transactional EXEC VM staging requires separate guest test")


if __name__ == "__main__":
    main()
