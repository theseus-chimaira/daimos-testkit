#!/usr/bin/env python3
"""Build host-reference DOBJ1 and DXR for native C89 relocations."""

from pathlib import Path
import struct
import subprocess
import sys


CASES = (
    "call-main", "call-provider", "data-main", "data-provider", "local-main"
)


def run(args):
    subprocess.run([str(a) for a in args], check=True)


def a7_pack(data):
    words = []
    for off in range(0, len(data), 5):
        w = 0
        for i, ch in enumerate(data[off:off + 5]):
            if ch == 0 or ch >= 128:
                raise ValueError("invalid assembler ASCII7 character")
            w |= ch << (29 - i * 7)
        words.append(w)
    return struct.pack("<" + "Q" * len(words), *words)


def main():
    if len(sys.argv) != 8:
        raise SystemExit("usage: make_fixtures_v1405.py SRC DEST KCC DAS "
                         "DLINK CSIX CRT0_DOBJ")
    source, target, kcc, das, dlink, csix, crt0 = sys.argv[1:]
    src = Path(source)
    out = Path(target)
    out.mkdir(parents=True, exist_ok=True)
    for stem in CASES:
        name = stem + "-v1405"
        c = src / (name + ".c")
        run((csix, "-e", c, out / (name + ".s6rec")))
        asm = out / (name + ".s")
        run((kcc, "-Pgnu99", "-O", "-x=pdp6", "-m=gas", "-S",
             c, "-o", asm))
        (out / (name + ".a7")).write_bytes(a7_pack(asm.read_bytes()))
        run((das, "-F", "-C", "-O", out / (name + ".dobj"), asm))

    syscall = Path(crt0).with_name("syscall.dobj")
    for stem, objs in (
        ("call", ("call-main", "call-provider")),
        ("data", ("data-main", "data-provider")),
        ("local", ("local-main",)),
    ):
        inputs = [out / (o + "-v1405.dobj") for o in objs]
        gold = out / (stem + "-gold-v1405.dxr")
        run((dlink, "-b", "020", "-o", gold, crt0, *inputs, syscall))
        print("V1405_GOLD_PASS", stem, gold.stat().st_size)


if __name__ == "__main__":
    main()
