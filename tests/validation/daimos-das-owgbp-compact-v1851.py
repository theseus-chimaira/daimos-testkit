#!/usr/bin/env python3
"""Independent oracle for all PDP-10 OWGBP selector encodings."""
import pathlib
import sys

GROUPS = ((0o46, 0o53, 6), (0o62, 0o66, 7),
          (0o55, 0o60, 8), (0o70, 0o73, 9), (0o75, 0o76, 18))
TARGET = 0o123456
MASK36 = 0o777777777777


def cases():
    for first, last, bits in GROUPS:
        for sel in range(first, last + 1):
            high = (sel - first) * bits + bits - 1
            word = (((35 - high) << 30) | (bits << 24) | TARGET) & MASK36
            yield sel, word


def create(path):
    rows = [".text", ".entry start", "start:"]
    for sel, _ in cases():
        rows.append("    OWGBP 0%o,GIW 0%o" % (sel, TARGET))
    path.write_text("\n".join(rows) + "\n", encoding="ascii")


def verify(path):
    data = path.read_bytes()
    if len(data) < 16 or len(data) % 8:
        raise AssertionError("not a complete DXR")
    words = [int.from_bytes(data[i:i + 8], "little") & MASK36
             for i in range(0, len(data), 8)]
    if ((words[0] >> 18) & 0o777777) != 0o447062:
        raise AssertionError("not a DXR image")
    image = (words[1] >> 18) & 0o777777
    expect = list(cases())
    if image != len(expect):
        raise AssertionError("image words=%d, wanted=%d" %
                             (image, len(expect)))
    for i, (sel, value) in enumerate(expect):
        if words[2 + i] != value:
            raise AssertionError("OWGBP selector 0%o: got 0%012o, wanted 0%012o" %
                                 (sel, words[2 + i], value))
    print("PASS: all %d OWGBP selectors match independent bit positions" %
          len(expect))


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: oracle.py generate|check FILE")
    operation, filename = sys.argv[1:]
    if operation == "generate":
        create(pathlib.Path(filename))
    elif operation == "check":
        verify(pathlib.Path(filename))
    else:
        raise SystemExit("unknown operation: " + operation)


if __name__ == "__main__":
    main()
